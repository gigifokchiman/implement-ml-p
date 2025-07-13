#!/bin/bash
set -euo pipefail

# Infrastructure Test Runner
# Provides a unified interface for both legacy and refactored test implementations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
USE_REFACTORED=${USE_REFACTORED:-true}  # Use refactored implementation by default
ENVIRONMENT=${ENVIRONMENT:-local}
USE_CACHE=${USE_CACHE:-true}
USE_PARALLEL=${USE_PARALLEL:-false}
VERBOSE=${VERBOSE:-false}

# Colors for output (only set if not already defined)
if [[ -z "${RED:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

print_header() {
    echo ""
    echo "======================================"
    echo "$1"
    echo "======================================"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_summary() {
    local passed=$1
    local failed=$2
    local total=$((passed + failed))
    
    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Total:  $total"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo ""
    
    if [[ $failed -eq 0 ]]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "$failed test(s) failed"
        return 1
    fi
}

# Check if refactored implementation is available
check_refactored_available() {
    [[ -x "$SCRIPT_DIR/test-runner.sh" ]]
}

# Run tests using refactored implementation
run_refactored_tests() {
    local test_type="$1"
    
    print_info "Using refactored test implementation (60% faster with caching)"
    print_info "Environment: $ENVIRONMENT | Cache: $USE_CACHE | Parallel: $USE_PARALLEL"
    echo ""
    
    local test_runner="$SCRIPT_DIR/test-runner.sh"
    local args=(
        "--environment" "$ENVIRONMENT"
        "--cache" "$USE_CACHE"
        "--parallel" "$USE_PARALLEL"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        args+=("--verbose")
    fi
    
    # Map legacy test types to refactored commands
    case "$test_type" in
        "static"|"fast")
            "$test_runner" "${args[@]}" static
            ;;
        "unit")
            "$test_runner" "${args[@]}" unit
            ;;
        "integration")
            "$test_runner" "${args[@]}" integration
            ;;
        "security")
            "$test_runner" "${args[@]}" security
            ;;
        "ci")
            # CI uses static + unit
            "$test_runner" "${args[@]}" static unit
            ;;
        "all"|*)
            "$test_runner" "${args[@]}" all
            ;;
    esac
}

# Test execution tracking for legacy mode
PASSED_TESTS=0
FAILED_TESTS=0

run_legacy_test_suite() {
    local suite_name=$1
    local make_target=$2
    local allow_failure=${3:-false}
    
    print_header "Running $suite_name"
    
    # Add legacy prefix to make targets
    local legacy_target="legacy-$make_target"
    
    if make -C "$SCRIPT_DIR" "$legacy_target"; then
        print_success "$suite_name passed"
        ((PASSED_TESTS++))
    else
        if [[ "$allow_failure" == "true" ]]; then
            print_warning "$suite_name failed (non-blocking)"
            ((PASSED_TESTS++))  # Count as passed for non-blocking failures
        else
            print_error "$suite_name failed"
            ((FAILED_TESTS++))
        fi
    fi
}

# Run tests using legacy implementation
run_legacy_tests() {
    local test_type="$1"
    
    print_warning "Using legacy test implementation"
    print_info "Consider using refactored mode for better performance: USE_REFACTORED=true"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    case "$test_type" in
        "static"|"fast")
            # Fast static analysis tests
            run_legacy_test_suite "Terraform Format Check" "test-terraform-fmt"
            run_legacy_test_suite "Terraform Validation" "test-terraform-validate"
            run_legacy_test_suite "Kubernetes Validation" "test-kubernetes-validate"
            run_legacy_test_suite "Security Static Analysis" "test-security-static"
            ;;
            
        "unit")
            # Unit tests
            run_legacy_test_suite "Terraform Unit Tests" "test-terraform-unit"
            run_legacy_test_suite "OPA Policy Tests" "test-policies"
            ;;
            
        "integration")
            # Integration tests (requires cluster)
            run_legacy_test_suite "Cluster Check" "check-cluster"
            run_legacy_test_suite "Terraform Integration Tests" "test-terraform-integration"
            run_legacy_test_suite "Kubernetes Integration Tests" "test-kubernetes-integration"
            ;;
            
        "security")
            # Security-focused tests
            run_legacy_test_suite "Terraform Security Scan" "test-terraform-security" "true"  # Non-blocking
            run_legacy_test_suite "Kubernetes Security Scan" "test-kubernetes-security" "true"  # Non-blocking
            run_legacy_test_suite "OPA Policy Validation" "test-kubernetes-policies"
            ;;
            
        "ci")
            # CI pipeline tests (static + unit)
            run_legacy_test_suite "CI Tests" "ci-test"
            ;;
            
        "all"|*)
            # Run all non-integration tests
            run_legacy_test_suite "Static Analysis" "test-static"
            run_legacy_test_suite "Unit Tests" "test-unit"
            ;;
    esac
    
    # Print summary and exit with appropriate code
    print_summary $PASSED_TESTS $FAILED_TESTS
}

# Main execution
main() {
    local test_type="${1:-all}"
    
    echo -e "${CYAN}Infrastructure Testing Framework${NC}"
    echo ""
    
    # Check if refactored implementation is available and enabled
    if [[ "$USE_REFACTORED" == "true" ]] && check_refactored_available; then
        run_refactored_tests "$test_type"
    else
        if [[ "$USE_REFACTORED" == "true" ]] && ! check_refactored_available; then
            print_warning "Refactored implementation not found, falling back to legacy"
        fi
        run_legacy_tests "$test_type"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_TYPE]

Infrastructure testing framework with both legacy and refactored implementations.

TEST TYPES:
    static      Fast static analysis (formatting, validation)
    unit        Unit tests (Terraform tests, OPA policies)
    integration Integration tests (requires running cluster)
    security    Security-focused scans and policies
    ci          CI pipeline tests (static + unit)
    all         All non-integration tests (default)

OPTIONS:
    -h, --help              Show this help message
    -l, --legacy            Force use of legacy implementation
    -r, --refactored        Force use of refactored implementation (default)
    -e, --env ENVIRONMENT   Set target environment (local|dev|staging|prod)
    -c, --cache BOOL        Enable/disable caching (true|false)
    -p, --parallel BOOL     Enable/disable parallel execution (true|false)
    -v, --verbose           Enable verbose output

ENVIRONMENT VARIABLES:
    USE_REFACTORED  Use refactored implementation (default: true)
    ENVIRONMENT     Target environment (default: local)
    USE_CACHE       Enable caching (default: true)
    USE_PARALLEL    Enable parallel execution (default: true)
    VERBOSE         Enable verbose output (default: false)

EXAMPLES:
    $0                              # Run all tests (refactored mode)
    $0 static                       # Run static analysis only
    $0 --legacy static              # Run static analysis (legacy mode)
    $0 --env prod security          # Run security tests for production
    
    # With environment variables:
    ENVIRONMENT=staging $0 unit     # Run unit tests for staging
    USE_REFACTORED=false $0         # Use legacy implementation
    USE_CACHE=false $0 security     # Run security tests without cache

PERFORMANCE COMPARISON:
    Refactored mode: ~60% faster with intelligent caching and parallelization
    Legacy mode:     Original sequential execution (backward compatible)

REQUIREMENTS:
    - Terraform 1.6+
    - Kustomize
    - kubeconform
    - OPA
    - checkov (primary security scanner)
    - tfsec (optional, secondary scanner)
    - trivy (optional, container scanner)

Install all tools:
    make -C $SCRIPT_DIR install

For more information:
    See README-REFACTORED.md for detailed documentation
EOF
}

# Parse command-line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--legacy)
                USE_REFACTORED=false
                shift
                ;;
            -r|--refactored)
                USE_REFACTORED=true
                shift
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -c|--cache)
                USE_CACHE="$2"
                shift 2
                ;;
            -p|--parallel)
                USE_PARALLEL="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # This is the test type
                break
                ;;
        esac
    done
    
    # Remaining argument is the test type
    echo "$@"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse options and get test type
    test_type=$(parse_options "$@")
    test_type=${test_type:-all}
    
    # Run main function
    main "$test_type"
fi