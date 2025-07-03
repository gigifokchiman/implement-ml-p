#!/bin/bash
set -euo pipefail

# Modern infrastructure test runner
# Uses proper tools instead of brittle shell scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "======================================"
    echo "$1"
    echo "======================================"
    echo ""
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
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ $failed test(s) failed${NC}"
        return 1
    fi
}

# Test execution tracking
PASSED_TESTS=0
FAILED_TESTS=0

run_test_suite() {
    local suite_name=$1
    local make_target=$2
    local allow_failure=${3:-false}
    
    print_header "Running $suite_name"
    
    if make -C "$SCRIPT_DIR" "$make_target"; then
        echo -e "${GREEN}✅ $suite_name passed${NC}"
        ((PASSED_TESTS++))
    else
        if [[ "$allow_failure" == "true" ]]; then
            echo -e "${YELLOW}⚠️  $suite_name failed (non-blocking)${NC}"
            ((PASSED_TESTS++))  # Count as passed for non-blocking failures
        else
            echo -e "${RED}❌ $suite_name failed${NC}"
            ((FAILED_TESTS++))
        fi
    fi
}

# Main execution
main() {
    local test_type="${1:-all}"
    
    echo -e "${BLUE}Infrastructure Testing Framework${NC}"
    echo "Test Type: $test_type"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    case "$test_type" in
        "static"|"fast")
            # Fast static analysis tests
            run_test_suite "Terraform Format Check" "test-terraform-fmt"
            run_test_suite "Terraform Validation" "test-terraform-validate"
            run_test_suite "Kubernetes Validation" "test-kubernetes-validate"
            run_test_suite "Security Static Analysis" "test-security-static"
            ;;
            
        "unit")
            # Unit tests
            run_test_suite "Terraform Unit Tests" "test-terraform-unit"
            run_test_suite "OPA Policy Tests" "test-policies"
            ;;
            
        "integration")
            # Integration tests (requires cluster)
            run_test_suite "Cluster Check" "check-cluster"
            run_test_suite "Terraform Integration Tests" "test-terraform-integration"
            run_test_suite "Kubernetes Integration Tests" "test-kubernetes-integration"
            ;;
            
        "security")
            # Security-focused tests
            run_test_suite "Terraform Security Scan" "test-terraform-security" "true"  # Non-blocking
            run_test_suite "Kubernetes Security Scan" "test-kubernetes-security" "true"  # Non-blocking
            run_test_suite "OPA Policy Validation" "test-kubernetes-policies"
            ;;
            
        "ci")
            # CI pipeline tests (static + unit)
            run_test_suite "CI Tests" "ci-test"
            ;;
            
        "all"|*)
            # Run all non-integration tests
            run_test_suite "Static Analysis" "test-static"
            run_test_suite "Unit Tests" "test-unit"
            ;;
    esac
    
    # Print summary and exit with appropriate code
    print_summary $PASSED_TESTS $FAILED_TESTS
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [TEST_TYPE]

Modern infrastructure testing using proper tools.

TEST TYPES:
    static      Fast static analysis (formatting, validation)
    unit        Unit tests (Terraform tests, OPA policies)
    integration Integration tests (requires running cluster)
    security    Security-focused scans and policies
    ci          CI pipeline tests (static + unit)
    all         All non-integration tests (default)

EXAMPLES:
    $0              # Run static + unit tests
    $0 static       # Run only static analysis
    $0 integration  # Run integration tests

REQUIREMENTS:
    - Terraform 1.6+
    - Kustomize
    - kubeconform
    - OPA
    - tfsec/checkov (for security scans)
    - gigifokchiman/kind provider (for local environment)

Install all tools:
    make -C $SCRIPT_DIR install
    # For Kind provider (local development):
    cd ../scripts && ./download-kind-provider.sh
EOF
}

# Parse arguments
case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac