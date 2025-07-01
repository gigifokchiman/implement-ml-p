#!/bin/bash
set -euo pipefail

# Simple test runner that focuses on basic validation
# Bypasses complex security scans that may have issues

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

run_simple_test() {
    local test_name=$1
    local make_target=$2
    
    echo -e "${BLUE}🧪 Running $test_name...${NC}"
    
    if make -C "$SCRIPT_DIR" "$make_target" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        echo "   Run 'make $make_target' for details"
        ((FAILED_TESTS++))
    fi
}

# Main execution
main() {
    local test_type="${1:-basic}"
    
    echo -e "${BLUE}Infrastructure Testing Framework (Simple)${NC}"
    echo "Test Type: $test_type"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    case "$test_type" in
        "format"|"fmt")
            # Just formatting
            run_simple_test "Terraform Format Check" "test-terraform-fmt"
            ;;
            
        "validate")
            # Just validation
            run_simple_test "Terraform Format Check" "test-terraform-fmt"
            run_simple_test "Terraform Validation" "test-terraform-validate"
            run_simple_test "Kubernetes Validation" "test-kubernetes-validate"
            ;;
            
        "basic"|*)
            # Basic tests without security scans
            run_simple_test "Terraform Format Check" "test-terraform-fmt"
            run_simple_test "Terraform Validation" "test-terraform-validate"
            run_simple_test "Kubernetes Validation" "test-kubernetes-validate"
            run_simple_test "OPA Policy Tests" "test-policies"
            ;;
    esac
    
    # Print summary and exit with appropriate code
    print_summary $PASSED_TESTS $FAILED_TESTS
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [TEST_TYPE]

Simple infrastructure testing without complex security scans.

TEST TYPES:
    format      Just check formatting
    validate    Format + validation only
    basic       Format + validation + policy tests (default)

EXAMPLES:
    $0          # Run basic tests
    $0 format   # Just check formatting
    $0 validate # Format and validation only

This is a simplified test runner that bypasses complex security scans
which may need more configuration. Use 'run-tests.sh' for full testing.
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