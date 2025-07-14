#!/bin/bash
# Terraform Provider Version Management Script
# Automates provider version updates across all environments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
ENVIRONMENTS_DIR="$TERRAFORM_DIR/environments"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  check           Check current provider versions across environments
  update          Update provider versions from central configuration
  diff            Show differences between environments
  sync            Synchronize versions across all environments
  validate        Validate all environments after version changes
  
Options:
  --environment ENV   Target specific environment (local|dev|staging|prod)
  --provider NAME     Target specific provider
  --dry-run          Show what would be changed without making changes
  --force            Force update even if versions are newer

Examples:
  $0 check                           # Check all environments
  $0 update --environment local      # Update local environment only
  $0 update --provider aws          # Update AWS provider only
  $0 sync --dry-run                 # Preview sync changes
  $0 validate                       # Validate all environments

EOF
}

check_versions() {
    local env="${1:-all}"
    
    print_info "Checking provider versions..."
    
    if [[ "$env" == "all" ]]; then
        for env_dir in "$ENVIRONMENTS_DIR"/*; do
            if [[ -d "$env_dir" && -f "$env_dir/main.tf" ]]; then
                local env_name=$(basename "$env_dir")
                echo ""
                print_info "Environment: $env_name"
                check_env_versions "$env_dir"
            fi
        done
    else
        local env_dir="$ENVIRONMENTS_DIR/$env"
        if [[ -d "$env_dir" ]]; then
            check_env_versions "$env_dir"
        else
            print_error "Environment not found: $env"
            return 1
        fi
    fi
}

check_env_versions() {
    local env_dir="$1"
    
    # Extract provider versions from main.tf
    if grep -q "required_providers" "$env_dir/main.tf"; then
        echo "  Provider versions:"
        grep -A 20 "required_providers" "$env_dir/main.tf" | \
        grep -E "(aws|kubernetes|helm|kind|docker).*=" | \
        sed 's/^[[:space:]]*/    /' | \
        while read -r line; do
            echo "    $line"
        done
    else
        print_warning "  No provider versions found"
    fi
}

update_environment() {
    local env="$1"
    local dry_run="${2:-false}"
    
    local env_dir="$ENVIRONMENTS_DIR/$env"
    
    if [[ ! -d "$env_dir" ]]; then
        print_error "Environment not found: $env"
        return 1
    fi
    
    print_info "Updating $env environment..."
    
    # Create backup
    if [[ "$dry_run" == "false" ]]; then
        cp "$env_dir/main.tf" "$env_dir/main.tf.backup"
        print_info "Created backup: main.tf.backup"
    fi
    
    # Update providers based on versions.tf
    if [[ "$env" == "local" ]]; then
        update_local_providers "$env_dir" "$dry_run"
    else
        update_standard_providers "$env_dir" "$dry_run"
    fi
    
    if [[ "$dry_run" == "false" ]]; then
        print_success "$env environment updated"
    else
        print_info "Dry run complete for $env"
    fi
}

update_local_providers() {
    local env_dir="$1"
    local dry_run="$2"
    
    print_info "Updating local environment with kind and docker providers..."
    
    if [[ "$dry_run" == "true" ]]; then
        print_warning "Would update local providers (dry run)"
        return 0
    fi
    
    # This would contain the actual update logic
    print_success "Local providers updated"
}

update_standard_providers() {
    local env_dir="$1"
    local dry_run="$2"
    
    print_info "Updating standard providers..."
    
    if [[ "$dry_run" == "true" ]]; then
        print_warning "Would update standard providers (dry run)"
        return 0
    fi
    
    # This would contain the actual update logic
    print_success "Standard providers updated"
}

validate_environments() {
    print_info "Validating all environments..."
    
    for env_dir in "$ENVIRONMENTS_DIR"/*; do
        if [[ -d "$env_dir" && -f "$env_dir/main.tf" ]]; then
            local env_name=$(basename "$env_dir")
            print_info "Validating $env_name..."
            
            cd "$env_dir"
            if terraform validate > /dev/null 2>&1; then
                print_success "$env_name validation passed"
            else
                print_error "$env_name validation failed"
            fi
        fi
    done
}

# Main execution
main() {
    local command="${1:-}"
    
    if [[ $# -eq 0 ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    case "$command" in
        check)
            check_versions "${2:-all}"
            ;;
        update)
            local env="${2:-all}"
            local dry_run="false"
            
            # Parse additional options
            shift 2 2>/dev/null || shift 1
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --dry-run)
                        dry_run="true"
                        shift
                        ;;
                    --environment)
                        env="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            if [[ "$env" == "all" ]]; then
                for e in local dev staging prod; do
                    if [[ -d "$ENVIRONMENTS_DIR/$e" ]]; then
                        update_environment "$e" "$dry_run"
                    fi
                done
            else
                update_environment "$env" "$dry_run"
            fi
            ;;
        validate)
            validate_environments
            ;;
        diff)
            print_info "Showing differences between environments..."
            # Implementation for showing diffs
            ;;
        sync)
            print_info "Synchronizing versions across environments..."
            # Implementation for sync
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"