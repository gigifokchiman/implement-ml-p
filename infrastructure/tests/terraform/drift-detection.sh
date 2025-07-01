#!/bin/bash
set -euo pipefail

# Terraform drift detection script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Environment to check
ENVIRONMENT="${1:-local}"
DRIFT_THRESHOLD="${DRIFT_THRESHOLD:-5}"  # Number of drifted resources to trigger alert

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(local|dev|staging|prod)$ ]]; then
    error "Invalid environment: $ENVIRONMENT. Must be one of: local, dev, staging, prod"
    exit 1
fi

log "Starting Terraform drift detection for environment: $ENVIRONMENT"

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        error "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check if environment directory exists
    local env_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    if [ ! -d "$env_dir" ]; then
        error "Environment directory not found: $env_dir"
        exit 1
    fi
    
    # Check if terraform is initialized
    if [ ! -d "$env_dir/.terraform" ]; then
        warn "Terraform not initialized for $ENVIRONMENT. Initializing..."
        cd "$env_dir"
        terraform init
        cd - > /dev/null
    fi
    
    success "Prerequisites check passed"
}

# Backup current state
backup_state() {
    local env_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    local backup_dir="$SCRIPT_DIR/drift-backups/$ENVIRONMENT"
    
    log "Backing up current Terraform state..."
    
    mkdir -p "$backup_dir"
    
    cd "$env_dir"
    
    # Backup state file
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate "$backup_dir/terraform.tfstate.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Backup plan output
    terraform show -json > "$backup_dir/current-state.$(date +%Y%m%d-%H%M%S).json"
    
    cd - > /dev/null
    
    success "State backup completed"
}

# Detect drift
detect_drift() {
    local env_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    local output_file="$SCRIPT_DIR/drift-report-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).json"
    
    log "Detecting infrastructure drift..."
    
    cd "$env_dir"
    
    # Generate plan to detect drift
    local plan_file="/tmp/drift-plan-$ENVIRONMENT.tfplan"
    
    if terraform plan -detailed-exitcode -out="$plan_file" -no-color > /tmp/terraform-plan-output.txt 2>&1; then
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            success "No drift detected - infrastructure matches configuration"
            echo '{"status": "no_drift", "changes": [], "timestamp": "'$(date -Iseconds)'"}' > "$output_file"
            return 0
        elif [ $exit_code -eq 2 ]; then
            warn "Drift detected - analyzing changes..."
            
            # Convert plan to JSON for analysis
            terraform show -json "$plan_file" > "$output_file"
            
            # Analyze the drift
            analyze_drift "$output_file"
            
            return 1
        else
            error "Terraform plan failed"
            cat /tmp/terraform-plan-output.txt
            return 2
        fi
    else
        error "Failed to run terraform plan"
        cat /tmp/terraform-plan-output.txt
        return 2
    fi
    
    cd - > /dev/null
}

# Analyze drift details
analyze_drift() {
    local plan_file="$1"
    
    log "Analyzing drift details..."
    
    # Extract resource changes
    local changes=$(jq -r '.resource_changes[] | select(.change.actions[] | contains("update") or contains("delete") or contains("create"))' "$plan_file" 2>/dev/null || echo "[]")
    
    if [ -n "$changes" ] && [ "$changes" != "[]" ]; then
        local change_count=$(echo "$changes" | jq -s 'length' 2>/dev/null || echo "0")
        
        warn "Found $change_count drifted resources"
        
        # Log details of each change
        echo "$changes" | jq -r '.address + " (" + (.change.actions | join(",")) + ")"' 2>/dev/null | while read -r line; do
            warn "  - $line"
        done
        
        # Check if drift exceeds threshold
        if [ "$change_count" -gt "$DRIFT_THRESHOLD" ]; then
            error "Drift threshold exceeded: $change_count > $DRIFT_THRESHOLD"
            return 1
        fi
    else
        success "No significant drift detected"
    fi
}

# Generate drift report
generate_report() {
    local drift_files=("$SCRIPT_DIR"/drift-report-$ENVIRONMENT-*.json)
    local latest_report=""
    
    # Find the latest report
    for file in "${drift_files[@]}"; do
        if [ -f "$file" ]; then
            latest_report="$file"
        fi
    done
    
    if [ -z "$latest_report" ]; then
        warn "No drift report found"
        return 1
    fi
    
    log "Generating drift analysis report..."
    
    local report_file="$SCRIPT_DIR/drift-analysis-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Terraform Drift Detection Report

**Environment:** $ENVIRONMENT
**Date:** $(date)
**Threshold:** $DRIFT_THRESHOLD changes

## Summary

EOF
    
    # Analyze the latest report
    if [ -f "$latest_report" ]; then
        local status=$(jq -r '.status // "unknown"' "$latest_report" 2>/dev/null || echo "unknown")
        
        if [ "$status" = "no_drift" ]; then
            echo "✅ **Status:** No drift detected" >> "$report_file"
            echo "The infrastructure configuration matches the deployed state." >> "$report_file"
        else
            local change_count=$(jq '[.resource_changes[] | select(.change.actions[] | contains("update") or contains("delete") or contains("create"))] | length' "$latest_report" 2>/dev/null || echo "0")
            
            if [ "$change_count" -gt 0 ]; then
                echo "⚠️ **Status:** Drift detected ($change_count changes)" >> "$report_file"
                echo "" >> "$report_file"
                echo "## Drifted Resources" >> "$report_file"
                echo "" >> "$report_file"
                echo "| Resource | Action | Type |" >> "$report_file"
                echo "|----------|--------|------|" >> "$report_file"
                
                # Extract resource details
                jq -r '.resource_changes[] | select(.change.actions[] | contains("update") or contains("delete") or contains("create")) | "| " + .address + " | " + (.change.actions | join(",")) + " | " + .type + " |"' "$latest_report" 2>/dev/null >> "$report_file" || true
            else
                echo "✅ **Status:** No significant drift" >> "$report_file"
            fi
        fi
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

1. **Review Changes**: Examine all drifted resources to understand the cause
2. **Update Configuration**: Update Terraform configuration to match desired state
3. **Apply Changes**: Run \`terraform apply\` to remediate drift
4. **Investigate**: Determine why drift occurred (manual changes, external automation, etc.)

## Next Steps

- [ ] Review drifted resources
- [ ] Update Terraform configuration if needed
- [ ] Apply changes to remediate drift
- [ ] Implement preventive measures

## Commands

\`\`\`bash
# Review the plan
cd terraform/environments/$ENVIRONMENT
terraform plan

# Apply changes
terraform apply

# Refresh state
terraform refresh
\`\`\`

EOF
    
    success "Drift analysis report generated: $report_file"
    echo "$report_file"
}

# Send notifications (if configured)
send_notifications() {
    local drift_status="$1"
    local report_file="$2"
    
    # Slack notification (if webhook URL is configured)
    if [ -n "${SLACK_WEBHOOK_URL:-}" ] && [ "$drift_status" != "0" ]; then
        log "Sending Slack notification..."
        
        curl -X POST -H 'Content-type: application/json' \
            --data '{
                "text": "🚨 Terraform Drift Detected",
                "attachments": [
                    {
                        "color": "warning",
                        "fields": [
                            {
                                "title": "Environment",
                                "value": "'$ENVIRONMENT'",
                                "short": true
                            },
                            {
                                "title": "Status",
                                "value": "Drift detected",
                                "short": true
                            }
                        ]
                    }
                ]
            }' \
            "$SLACK_WEBHOOK_URL" || warn "Failed to send Slack notification"
    fi
    
    # Email notification (if configured)
    if [ -n "${EMAIL_TO:-}" ] && [ "$drift_status" != "0" ]; then
        log "Sending email notification..."
        
        if command -v mail &> /dev/null; then
            echo "Terraform drift detected in environment: $ENVIRONMENT" | \
                mail -s "Terraform Drift Alert - $ENVIRONMENT" "$EMAIL_TO" || \
                warn "Failed to send email notification"
        else
            warn "Mail command not available for email notifications"
        fi
    fi
}

# Cleanup old reports
cleanup_old_reports() {
    log "Cleaning up old drift reports..."
    
    # Keep only the last 10 reports per environment
    find "$SCRIPT_DIR" -name "drift-report-$ENVIRONMENT-*.json" -type f | \
        sort -r | tail -n +11 | xargs rm -f
    
    find "$SCRIPT_DIR" -name "drift-analysis-$ENVIRONMENT-*.md" -type f | \
        sort -r | tail -n +6 | xargs rm -f
    
    # Clean up old backups (keep last 5)
    if [ -d "$SCRIPT_DIR/drift-backups/$ENVIRONMENT" ]; then
        find "$SCRIPT_DIR/drift-backups/$ENVIRONMENT" -name "*.json" -type f | \
            sort -r | tail -n +6 | xargs rm -f
        
        find "$SCRIPT_DIR/drift-backups/$ENVIRONMENT" -name "terraform.tfstate.*" -type f | \
            sort -r | tail -n +6 | xargs rm -f
    fi
    
    success "Cleanup completed"
}

# Main execution
main() {
    local overall_status=0
    
    # Create output directories
    mkdir -p "$SCRIPT_DIR"
    mkdir -p "$SCRIPT_DIR/drift-backups"
    
    # Run drift detection
    check_prerequisites
    backup_state
    
    if detect_drift; then
        success "No drift detected in $ENVIRONMENT environment"
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            warn "Drift detected in $ENVIRONMENT environment"
            overall_status=1
        else
            error "Drift detection failed for $ENVIRONMENT environment"
            overall_status=2
        fi
    fi
    
    # Generate report
    local report_file=$(generate_report)
    
    # Send notifications if drift detected
    send_notifications "$overall_status" "$report_file"
    
    # Cleanup old files
    cleanup_old_reports
    
    if [ $overall_status -eq 0 ]; then
        success "Terraform drift detection completed successfully"
    elif [ $overall_status -eq 1 ]; then
        warn "Terraform drift detection completed with drift found"
        log "Report: $report_file"
    else
        error "Terraform drift detection failed"
        log "Report: $report_file"
    fi
    
    return $overall_status
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT]

Detect Terraform infrastructure drift for the specified environment.

ARGUMENTS:
    ENVIRONMENT    Environment to check (local|dev|staging|prod) [default: local]

ENVIRONMENT VARIABLES:
    DRIFT_THRESHOLD    Number of changes to trigger alert [default: 5]
    SLACK_WEBHOOK_URL  Slack webhook URL for notifications
    EMAIL_TO          Email address for notifications

EXAMPLES:
    $0 local          # Check local environment
    $0 prod           # Check production environment
    DRIFT_THRESHOLD=1 $0 dev  # Check dev with threshold of 1

EOF
}

# Handle command line arguments
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi