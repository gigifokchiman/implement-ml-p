#!/bin/bash
# Terraform format checking (static analysis)
# Execution time: < 10 seconds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/utils/common.sh"

# Run terraform format check
run_terraform_fmt_check() {
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    
    print_header "Terraform Format Check"
    
    if [[ ! -d "$terraform_dir" ]]; then
        print_error "Terraform directory not found: $terraform_dir"
        return 1
    fi
    
    print_info "Checking Terraform formatting in: $terraform_dir"
    
    if cd "$terraform_dir" && terraform fmt -check -recursive; then
        print_success "Terraform formatting is correct"
        return 0
    else
        print_error "Terraform formatting issues found"
        print_info "Run 'terraform fmt -recursive' to fix formatting"
        return 1
    fi
}

# Fix terraform formatting
fix_terraform_fmt() {
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    
    print_header "Fixing Terraform Format"
    
    if [[ ! -d "$terraform_dir" ]]; then
        print_error "Terraform directory not found: $terraform_dir"
        return 1
    fi
    
    print_info "Fixing Terraform formatting in: $terraform_dir"
    
    if cd "$terraform_dir" && terraform fmt -recursive; then
        print_success "Terraform formatting fixed"
        return 0
    else
        print_error "Failed to fix Terraform formatting"
        return 1
    fi
}

# Main function
main() {
    case "${1:-check}" in
        "check")
            run_terraform_fmt_check
            ;;
        "fix")
            fix_terraform_fmt
            ;;
        *)
            echo "Usage: $0 {check|fix}"
            echo "  check - Check Terraform formatting (default)"
            echo "  fix   - Fix Terraform formatting"
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi