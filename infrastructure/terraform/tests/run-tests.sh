#!/bin/bash
set -euo pipefail

# Infrastructure Testing Script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test statistics
total_tests=0
passed_tests=0
failed_tests=0

run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .tftest.hcl)
    
    log "Running test: $test_name"
    
    cd "$PROJECT_ROOT"
    
    if terraform test "$test_file"; then
        success "Test passed: $test_name"
        ((passed_tests++))
    else
        error "Test failed: $test_name"
        ((failed_tests++))
    fi
    
    ((total_tests++))
}

run_unit_tests() {
    log "Running unit tests..."
    
    for test_file in "$SCRIPT_DIR/unit/"*.tftest.hcl; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file"
        fi
    done
}

run_integration_tests() {
    log "Running integration tests..."
    
    for test_file in "$SCRIPT_DIR/integration/"*.tftest.hcl; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file"
        fi
    done
}

validate_terraform() {
    log "Validating Terraform configurations..."
    
    cd "$PROJECT_ROOT"
    
    # Validate all modules
    for module_dir in modules/*/; do
        if [[ -d "$module_dir" ]]; then
            log "Validating module: $(basename "$module_dir")"
            cd "$module_dir"
            terraform init -backend=false
            terraform validate
            cd "$PROJECT_ROOT"
        fi
    done
    
    # Validate all environments
    for env_dir in environments/*/; do
        if [[ -d "$env_dir" && $(basename "$env_dir") != "_shared" ]]; then
            log "Validating environment: $(basename "$env_dir")"
            cd "$env_dir"
            terraform init -backend=false
            terraform validate
            cd "$PROJECT_ROOT"
        fi
    done
}

format_check() {
    log "Checking Terraform formatting..."
    
    cd "$PROJECT_ROOT"
    
    if ! terraform fmt -check -recursive; then
        error "Terraform files are not properly formatted"
        warn "Run 'terraform fmt -recursive' to fix formatting"
        return 1
    else
        success "All Terraform files are properly formatted"
    fi
}

show_summary() {
    echo ""
    log "Test Summary:"
    echo "  Total tests:  $total_tests"
    echo "  Passed tests: $passed_tests"
    echo "  Failed tests: $failed_tests"
    
    if [[ $failed_tests -eq 0 ]]; then
        success "All tests passed! 🎉"
        return 0
    else
        error "$failed_tests test(s) failed"
        return 1
    fi
}

main() {
    log "Starting infrastructure tests..."
    
    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        error "terraform not found. Please install terraform."
        exit 1
    fi
    
    # Run format check
    format_check
    
    # Run validation
    validate_terraform
    
    # Run unit tests
    run_unit_tests
    
    # Run integration tests
    run_integration_tests
    
    # Show summary
    show_summary
}

# Parse command line arguments
case "${1:-all}" in
    "unit")
        run_unit_tests
        show_summary
        ;;
    "integration")
        run_integration_tests
        show_summary
        ;;
    "validate")
        validate_terraform
        ;;
    "format")
        format_check
        ;;
    "all")
        main
        ;;
    *)
        echo "Usage: $0 [unit|integration|validate|format|all]"
        exit 1
        ;;
esac