#!/bin/bash
set -euo pipefail

# Local security scanning script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Check if required tools are installed
check_tools() {
    local missing_tools=()
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    # Check for Trivy
    if ! command -v trivy &> /dev/null; then
        warn "Trivy not found. Installing..."
        install_trivy
    fi
    
    # Check for tfsec
    if ! command -v tfsec &> /dev/null; then
        warn "tfsec not found. Installing..."
        install_tfsec
    fi
    
    # Check for checkov
    if ! command -v checkov &> /dev/null; then
        warn "checkov not found. Installing..."
        install_checkov
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install the missing tools and try again"
        exit 1
    fi
}

# Install Trivy
install_trivy() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install trivy
        else
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        fi
    else
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    fi
}

# Install tfsec
install_tfsec() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install tfsec
        else
            curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
        fi
    else
        curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    fi
}

# Install checkov
install_checkov() {
    if command -v pip3 &> /dev/null; then
        pip3 install checkov
    elif command -v pip &> /dev/null; then
        pip install checkov
    else
        error "Python pip not found. Please install Python and pip to use checkov"
    fi
}

# Scan container images
scan_containers() {
    log "Scanning container images for vulnerabilities..."
    
    local images=("ml-platform-backend" "ml-platform-frontend")
    local scan_failed=false
    
    for image in "${images[@]}"; do
        log "Scanning image: $image"
        
        # Build image if it doesn't exist
        if ! docker image inspect "$image:latest" &> /dev/null; then
            if [ -d "$PROJECT_ROOT/app/${image#ml-platform-}" ]; then
                log "Building image: $image"
                docker build -t "$image:latest" "$PROJECT_ROOT/app/${image#ml-platform-}"
            else
                warn "Image $image not found and cannot build"
                continue
            fi
        fi
        
        # Scan with Trivy
        local output_file="$SCRIPT_DIR/trivy-${image#ml-platform-}-results.json"
        if trivy image --format json --output "$output_file" "$image:latest"; then
            success "Trivy scan completed for $image"
            
            # Check for critical vulnerabilities
            local critical_count=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$output_file" 2>/dev/null || echo "0")
            local high_count=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$output_file" 2>/dev/null || echo "0")
            
            if [ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]; then
                warn "$image has $critical_count CRITICAL and $high_count HIGH vulnerabilities"
                scan_failed=true
            fi
        else
            error "Trivy scan failed for $image"
            scan_failed=true
        fi
    done
    
    if [ "$scan_failed" = true ]; then
        error "Container vulnerability scan found issues"
        return 1
    else
        success "Container vulnerability scan completed successfully"
        return 0
    fi
}

# Scan Terraform infrastructure
scan_terraform() {
    log "Scanning Terraform infrastructure for security issues..."
    
    local terraform_dir="$PROJECT_ROOT/terraform"
    local scan_failed=false
    
    if [ ! -d "$terraform_dir" ]; then
        warn "Terraform directory not found at $terraform_dir"
        return 0
    fi
    
    # Scan with tfsec
    log "Running tfsec scan..."
    local tfsec_output="$SCRIPT_DIR/tfsec-results.json"
    if tfsec "$terraform_dir" --format json --out "$tfsec_output" --exclude-downloaded-modules; then
        success "tfsec scan completed"
        
        # Check for critical issues
        local critical_count=$(jq '[.results[] | select(.severity == "CRITICAL")] | length' "$tfsec_output" 2>/dev/null || echo "0")
        local high_count=$(jq '[.results[] | select(.severity == "HIGH")] | length' "$tfsec_output" 2>/dev/null || echo "0")
        
        if [ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]; then
            warn "Found $critical_count CRITICAL and $high_count HIGH security issues in Terraform"
            scan_failed=true
        fi
    else
        error "tfsec scan failed"
        scan_failed=true
    fi
    
    # Scan with checkov
    log "Running checkov scan..."
    local checkov_output="$SCRIPT_DIR/checkov-results.json"
    if checkov -d "$terraform_dir" --output json --output-file "$checkov_output"; then
        success "checkov scan completed"
        
        # Check for failed checks
        local failed_count=$(jq '.summary.failed' "$checkov_output" 2>/dev/null || echo "0")
        if [ "$failed_count" -gt 0 ]; then
            warn "checkov found $failed_count failed security checks"
            scan_failed=true
        fi
    else
        error "checkov scan failed"
        scan_failed=true
    fi
    
    if [ "$scan_failed" = true ]; then
        error "Infrastructure security scan found issues"
        return 1
    else
        success "Infrastructure security scan completed successfully"
        return 0
    fi
}

# Scan Kubernetes manifests
scan_kubernetes() {
    log "Scanning Kubernetes manifests for security issues..."
    
    local k8s_dir="$PROJECT_ROOT/kubernetes"
    local scan_failed=false
    
    if [ ! -d "$k8s_dir" ]; then
        warn "Kubernetes directory not found at $k8s_dir"
        return 0
    fi
    
    # Scan with trivy
    log "Running Trivy config scan on Kubernetes manifests..."
    local k8s_output="$SCRIPT_DIR/trivy-k8s-results.json"
    if trivy config --format json --output "$k8s_output" "$k8s_dir"; then
        success "Trivy Kubernetes scan completed"
        
        # Check for issues
        local medium_count=$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "MEDIUM")] | length' "$k8s_output" 2>/dev/null || echo "0")
        local high_count=$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH")] | length' "$k8s_output" 2>/dev/null || echo "0")
        local critical_count=$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "CRITICAL")] | length' "$k8s_output" 2>/dev/null || echo "0")
        
        if [ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]; then
            warn "Found $critical_count CRITICAL and $high_count HIGH issues in Kubernetes manifests"
            scan_failed=true
        fi
    else
        error "Trivy Kubernetes scan failed"
        scan_failed=true
    fi
    
    if [ "$scan_failed" = true ]; then
        error "Kubernetes security scan found issues"
        return 1
    else
        success "Kubernetes security scan completed successfully"
        return 0
    fi
}

# Scan for secrets
scan_secrets() {
    log "Scanning for exposed secrets..."
    
    # Install gitleaks if not present
    if ! command -v gitleaks &> /dev/null; then
        log "Installing gitleaks..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install gitleaks
            else
                curl -L https://github.com/zricethezav/gitleaks/releases/latest/download/gitleaks_darwin_x64.tar.gz | tar xz
                chmod +x gitleaks
                sudo mv gitleaks /usr/local/bin/
            fi
        else
            curl -L https://github.com/zricethezav/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz | tar xz
            chmod +x gitleaks
            sudo mv gitleaks /usr/local/bin/
        fi
    fi
    
    local secrets_output="$SCRIPT_DIR/gitleaks-results.json"
    cd "$PROJECT_ROOT"
    
    if gitleaks detect --report-format json --report-path "$secrets_output"; then
        success "Secret scan completed - no secrets found"
        return 0
    else
        if [ -f "$secrets_output" ]; then
            local secrets_count=$(jq '. | length' "$secrets_output" 2>/dev/null || echo "0")
            if [ "$secrets_count" -gt 0 ]; then
                error "Found $secrets_count potential secrets in the codebase"
                return 1
            fi
        fi
        warn "Secret scan completed with warnings"
        return 0
    fi
}

# Generate security report
generate_report() {
    log "Generating security scan report..."
    
    local report_file="$SCRIPT_DIR/security-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Security Scan Report

**Date:** $(date)
**Scanner Version:** Local Security Scanner v1.0

## Scan Summary

| Component | Scanner | Status | Critical | High | Medium | Low |
|-----------|---------|--------|----------|------|--------|-----|
EOF
    
    # Add container scan results
    for component in backend frontend; do
        if [ -f "$SCRIPT_DIR/trivy-${component}-results.json" ]; then
            local critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$SCRIPT_DIR/trivy-${component}-results.json" 2>/dev/null || echo "0")
            local high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$SCRIPT_DIR/trivy-${component}-results.json" 2>/dev/null || echo "0")
            local medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' "$SCRIPT_DIR/trivy-${component}-results.json" 2>/dev/null || echo "0")
            local low=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length' "$SCRIPT_DIR/trivy-${component}-results.json" 2>/dev/null || echo "0")
            
            local status="✅ PASS"
            if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
                status="❌ FAIL"
            fi
            
            echo "| $component | Trivy | $status | $critical | $high | $medium | $low |" >> "$report_file"
        fi
    done
    
    # Add infrastructure scan results
    if [ -f "$SCRIPT_DIR/tfsec-results.json" ]; then
        local critical=$(jq '[.results[] | select(.severity == "CRITICAL")] | length' "$SCRIPT_DIR/tfsec-results.json" 2>/dev/null || echo "0")
        local high=$(jq '[.results[] | select(.severity == "HIGH")] | length' "$SCRIPT_DIR/tfsec-results.json" 2>/dev/null || echo "0")
        
        local status="✅ PASS"
        if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
            status="❌ FAIL"
        fi
        
        echo "| Infrastructure | tfsec | $status | $critical | $high | - | - |" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Detailed Findings

### Container Vulnerabilities
EOF
    
    if [ -f "$SCRIPT_DIR/trivy-backend-results.json" ]; then
        echo "- Backend image scan results: \`trivy-backend-results.json\`" >> "$report_file"
    fi
    
    if [ -f "$SCRIPT_DIR/trivy-frontend-results.json" ]; then
        echo "- Frontend image scan results: \`trivy-frontend-results.json\`" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### Infrastructure Security
EOF
    
    if [ -f "$SCRIPT_DIR/tfsec-results.json" ]; then
        echo "- Terraform security scan: \`tfsec-results.json\`" >> "$report_file"
    fi
    
    if [ -f "$SCRIPT_DIR/checkov-results.json" ]; then
        echo "- Infrastructure compliance: \`checkov-results.json\`" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

1. **Address Critical Vulnerabilities**: Fix all CRITICAL severity issues immediately
2. **Update Dependencies**: Keep all dependencies up to date
3. **Infrastructure Hardening**: Follow security best practices for cloud resources
4. **Regular Scanning**: Integrate security scanning into CI/CD pipeline
5. **Secret Management**: Use proper secret management solutions

## Next Steps

- [ ] Review and remediate high-priority findings
- [ ] Update vulnerable dependencies
- [ ] Implement additional security controls
- [ ] Schedule regular security reviews

EOF
    
    success "Security report generated: $report_file"
    echo "$report_file"
}

# Main execution
main() {
    log "Starting local security scan..."
    
    # Create output directory
    mkdir -p "$SCRIPT_DIR"
    
    # Check required tools
    check_tools
    
    local overall_status=0
    
    # Run security scans
    if ! scan_containers; then
        overall_status=1
    fi
    
    if ! scan_terraform; then
        overall_status=1
    fi
    
    if ! scan_kubernetes; then
        overall_status=1
    fi
    
    if ! scan_secrets; then
        overall_status=1
    fi
    
    # Generate report
    local report_file=$(generate_report)
    
    if [ $overall_status -eq 0 ]; then
        success "Security scan completed successfully!"
    else
        error "Security scan completed with issues. Review the report: $report_file"
    fi
    
    log "Report available at: $report_file"
    return $overall_status
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi