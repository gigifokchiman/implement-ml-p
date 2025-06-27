#!/bin/bash
set -euo pipefail

# Unified test runner for all infrastructure tests
# Orchestrates Terraform, Kubernetes, security, and performance tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

# Default configuration
TEST_TYPE="basic"
SKIP_INTEGRATION=false
SKIP_SECURITY=false
SKIP_PERFORMANCE=false
ENVIRONMENT="local"
PARALLEL=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $timestamp - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $timestamp - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message" ;;
    esac
}

# Test execution tracking
declare -A TEST_RESULTS
declare -A TEST_DURATIONS

run_test_suite() {
    local suite_name="$1"
    local test_command="$2"
    local skip_condition="${3:-false}"
    
    if [[ "$skip_condition" == "true" ]]; then
        log "INFO" "Skipping $suite_name (disabled)"
        TEST_RESULTS["$suite_name"]="SKIPPED"
        return 0
    fi
    
    log "INFO" "Starting $suite_name"
    local start_time=$(date +%s)
    
    if eval "$test_command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "SUCCESS" "$suite_name completed successfully (${duration}s)"
        TEST_RESULTS["$suite_name"]="PASSED"
        TEST_DURATIONS["$suite_name"]="$duration"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "ERROR" "$suite_name failed (${duration}s)"
        TEST_RESULTS["$suite_name"]="FAILED"
        TEST_DURATIONS["$suite_name"]="$duration"
        return 1
    fi
}

# Parallel test execution
run_tests_parallel() {
    log "INFO" "Running tests in parallel mode"
    
    # Start all test suites in background
    local pids=()
    
    # Terraform validation
    (
        run_test_suite "Terraform Validation" "$SCRIPT_DIR/terraform/validate.sh" "false"
        echo $? > /tmp/terraform_result
    ) &
    pids+=($!)
    
    # Kubernetes validation
    (
        run_test_suite "Kubernetes Validation" "$SCRIPT_DIR/kubernetes/validate.sh" "false"
        echo $? > /tmp/kubernetes_result
    ) &
    pids+=($!)
    
    # Security tests (if not skipped)
    if [[ "$SKIP_SECURITY" == "false" ]]; then
        (
            run_test_suite "Security Tests" "$SCRIPT_DIR/security/scan.sh" "false"
            echo $? > /tmp/security_result
        ) &
        pids+=($!)
    fi
    
    # Wait for all parallel tests to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Collect results
    if [[ -f /tmp/terraform_result ]]; then
        if [[ "$(cat /tmp/terraform_result)" != "0" ]]; then
            TEST_RESULTS["Terraform Validation"]="FAILED"
        fi
        rm -f /tmp/terraform_result
    fi
    
    if [[ -f /tmp/kubernetes_result ]]; then
        if [[ "$(cat /tmp/kubernetes_result)" != "0" ]]; then
            TEST_RESULTS["Kubernetes Validation"]="FAILED"
        fi
        rm -f /tmp/kubernetes_result
    fi
    
    if [[ -f /tmp/security_result ]]; then
        if [[ "$(cat /tmp/security_result)" != "0" ]]; then
            TEST_RESULTS["Security Tests"]="FAILED"
        fi
        rm -f /tmp/security_result
    fi
    
    # Run sequential tests that require the previous tests to pass
    local validation_failed=false
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == "FAILED" ]]; then
            validation_failed=true
            break
        fi
    done
    
    if [[ "$validation_failed" == "true" ]]; then
        log "WARN" "Skipping integration and performance tests due to validation failures"
        TEST_RESULTS["Integration Tests"]="SKIPPED"
        TEST_RESULTS["Performance Tests"]="SKIPPED"
    else
        # Integration tests
        run_test_suite "Integration Tests" "$SCRIPT_DIR/integration/deploy-test.sh $TEST_TYPE" "$SKIP_INTEGRATION"
        
        # Performance tests
        run_test_suite "Performance Tests" "$SCRIPT_DIR/performance/load-test.sh $TEST_TYPE" "$SKIP_PERFORMANCE"
    fi
}

# Sequential test execution
run_tests_sequential() {
    log "INFO" "Running tests in sequential mode"
    
    local failed_tests=0
    
    # Core validation tests
    run_test_suite "Terraform Validation" "$SCRIPT_DIR/terraform/validate.sh" "false" || ((failed_tests++))
    run_test_suite "Kubernetes Validation" "$SCRIPT_DIR/kubernetes/validate.sh" "false" || ((failed_tests++))
    
    # Security tests
    run_test_suite "Security Tests" "$SCRIPT_DIR/security/scan.sh" "$SKIP_SECURITY" || ((failed_tests++))
    
    # Only run integration and performance tests if validation passes
    if [[ $failed_tests -eq 0 ]]; then
        # Integration tests
        run_test_suite "Integration Tests" "$SCRIPT_DIR/integration/deploy-test.sh $TEST_TYPE" "$SKIP_INTEGRATION" || ((failed_tests++))
        
        # Performance tests (only if integration passes)
        if [[ "${TEST_RESULTS["Integration Tests"]}" == "PASSED" ]]; then
            run_test_suite "Performance Tests" "$SCRIPT_DIR/performance/load-test.sh $TEST_TYPE" "$SKIP_PERFORMANCE" || ((failed_tests++))
        else
            log "WARN" "Skipping performance tests due to integration test failures"
            TEST_RESULTS["Performance Tests"]="SKIPPED"
        fi
    else
        log "WARN" "Skipping integration and performance tests due to validation failures"
        TEST_RESULTS["Integration Tests"]="SKIPPED"
        TEST_RESULTS["Performance Tests"]="SKIPPED"
    fi
    
    return $failed_tests
}

# Generate comprehensive test report
generate_test_report() {
    local report_file="$SCRIPT_DIR/test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# ML Platform Infrastructure Test Report

**Generated:** $(date)  
**Environment:** $ENVIRONMENT  
**Test Type:** $TEST_TYPE  
**Execution Mode:** $([ "$PARALLEL" == "true" ] && echo "Parallel" || echo "Sequential")

## Executive Summary

$(
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    for result in "${TEST_RESULTS[@]}"; do
        ((total_tests++))
        case "$result" in
            "PASSED") ((passed_tests++)) ;;
            "FAILED") ((failed_tests++)) ;;
            "SKIPPED") ((skipped_tests++)) ;;
        esac
    done
    
    echo "- **Total Test Suites:** $total_tests"
    echo "- **Passed:** $passed_tests"
    echo "- **Failed:** $failed_tests"
    echo "- **Skipped:** $skipped_tests"
    echo "- **Success Rate:** $(( passed_tests * 100 / (total_tests - skipped_tests) ))%"
)

## Test Results

| Test Suite | Status | Duration | Notes |
|------------|--------|----------|-------|
$(
    for suite in "Terraform Validation" "Kubernetes Validation" "Security Tests" "Integration Tests" "Performance Tests"; do
        local status="${TEST_RESULTS[$suite]:-"NOT RUN"}"
        local duration="${TEST_DURATIONS[$suite]:-"N/A"}"
        local icon
        
        case "$status" in
            "PASSED") icon="✅" ;;
            "FAILED") icon="❌" ;;
            "SKIPPED") icon="⏭️" ;;
            "NOT RUN") icon="⭕" ;;
        esac
        
        local notes=""
        case "$suite" in
            "Terraform Validation") notes="Infrastructure as Code validation" ;;
            "Kubernetes Validation") notes="Kubernetes manifest validation" ;;
            "Security Tests") notes="Security scanning and compliance" ;;
            "Integration Tests") notes="End-to-end deployment testing" ;;
            "Performance Tests") notes="Load testing and performance analysis" ;;
        esac
        
        echo "| $suite | $icon $status | ${duration}s | $notes |"
    done
)

## Detailed Results

### Terraform Validation
- **Purpose:** Validate infrastructure as code
- **Scope:** All environments (dev, staging, prod)
- **Tools:** terraform validate, terraform plan, checkov, tfsec
- **Status:** ${TEST_RESULTS["Terraform Validation"]:-"NOT RUN"}

### Kubernetes Validation  
- **Purpose:** Validate Kubernetes manifests and configurations
- **Scope:** All overlays (local, dev, staging, prod)
- **Tools:** kustomize, kubectl, kubesec, kube-score
- **Status:** ${TEST_RESULTS["Kubernetes Validation"]:-"NOT RUN"}

### Security Tests
- **Purpose:** Security scanning and compliance checking
- **Scope:** Infrastructure code, container images, secrets
- **Tools:** checkov, tfsec, trivy, gitleaks, kubesec
- **Status:** ${TEST_RESULTS["Security Tests"]:-"NOT RUN"}

### Integration Tests
- **Purpose:** End-to-end deployment and functionality testing
- **Scope:** Complete application stack deployment
- **Tools:** kind, kubectl, curl
- **Status:** ${TEST_RESULTS["Integration Tests"]:-"NOT RUN"}

### Performance Tests
- **Purpose:** Load testing and performance validation
- **Scope:** Application performance under load
- **Tools:** ab, wrk, kubectl top
- **Status:** ${TEST_RESULTS["Performance Tests"]:-"NOT RUN"}

## Recommendations

### If Tests Failed
$(
    local has_failures=false
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == "FAILED" ]]; then
            has_failures=true
            break
        fi
    done
    
    if [[ "$has_failures" == "true" ]]; then
        echo "1. Review detailed test logs for specific failure reasons"
        echo "2. Fix infrastructure configuration issues"
        echo "3. Re-run failed test suites"
        echo "4. Consider running tests in development environment first"
    else
        echo "All tests passed successfully!"
    fi
)

### Next Steps
1. **Development:** Ready for deployment to development environment
2. **Staging:** Run extended tests before promoting to staging
3. **Production:** Ensure all tests pass before production deployment
4. **Monitoring:** Set up continuous monitoring and alerting

## Environment-Specific Notes

### Local Development
- Uses Kind cluster for testing
- Limited resource constraints
- Suitable for basic validation

### Cloud Environments
- Requires AWS credentials for Terraform tests
- More comprehensive resource testing
- Production-like configurations

## Test Execution Commands

\`\`\`bash
# Run all tests
./tests/run-all.sh

# Run specific test types
./tests/run-all.sh --type extended --skip-performance
./tests/run-all.sh --parallel --environment dev

# Run individual test suites
./tests/terraform/validate.sh
./tests/kubernetes/validate.sh
./tests/security/scan.sh
./tests/integration/deploy-test.sh
./tests/performance/load-test.sh
\`\`\`

---
*Generated by ML Platform Infrastructure Test Suite*
EOF

    log "INFO" "Comprehensive test report generated: $report_file"
    echo ""
    echo "📊 Test Report: $report_file"
}

# Print test summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Infrastructure Test Summary"
    echo "=========================================="
    
    local total_duration=0
    for suite in "Terraform Validation" "Kubernetes Validation" "Security Tests" "Integration Tests" "Performance Tests"; do
        local status="${TEST_RESULTS[$suite]:-"NOT RUN"}"
        local duration="${TEST_DURATIONS[$suite]:-"0"}"
        total_duration=$((total_duration + duration))
        
        local icon
        case "$status" in
            "PASSED") icon="✅" ;;
            "FAILED") icon="❌" ;;
            "SKIPPED") icon="⏭️" ;;
            "NOT RUN") icon="⭕" ;;
        esac
        
        printf "%-25s %s %-8s (%ss)\n" "$suite" "$icon" "$status" "$duration"
    done
    
    echo ""
    echo "Total execution time: ${total_duration}s"
    
    # Count results
    local passed=0 failed=0 skipped=0
    for result in "${TEST_RESULTS[@]}"; do
        case "$result" in
            "PASSED") ((passed++)) ;;
            "FAILED") ((failed++)) ;;
            "SKIPPED") ((skipped++)) ;;
        esac
    done
    
    echo "Results: $passed passed, $failed failed, $skipped skipped"
    
    if [[ $failed -eq 0 ]]; then
        log "SUCCESS" "All infrastructure tests completed successfully!"
    else
        log "ERROR" "$failed test suite(s) failed"
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive infrastructure tests for ML Platform

OPTIONS:
    -t, --type TYPE          Test type: basic, extended (default: basic)
    -e, --environment ENV    Target environment (default: local)
    -p, --parallel          Run tests in parallel where possible
    --skip-integration      Skip integration tests
    --skip-security         Skip security tests  
    --skip-performance      Skip performance tests
    -h, --help              Show this help message

TEST TYPES:
    basic                   Core validation tests (terraform, kubernetes)
    extended                All tests including integration and performance

EXAMPLES:
    $0                                    # Run basic tests
    $0 --type extended                   # Run all tests
    $0 --parallel --skip-performance     # Parallel execution, no performance tests
    $0 --environment dev --type extended # Extended tests for dev environment

DEPENDENCIES:
    Required: terraform, kubectl, kustomize
    Optional: checkov, tfsec, trivy, ab, wrk (for extended testing)
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        --skip-integration)
            SKIP_INTEGRATION=true
            shift
            ;;
        --skip-security)
            SKIP_SECURITY=true
            shift
            ;;
        --skip-performance)
            SKIP_PERFORMANCE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate test type
case "$TEST_TYPE" in
    "basic"|"extended") ;;
    *)
        log "ERROR" "Invalid test type: $TEST_TYPE"
        usage
        exit 1
        ;;
esac

# Adjust skips based on test type
if [[ "$TEST_TYPE" == "basic" ]]; then
    SKIP_INTEGRATION=true
    SKIP_PERFORMANCE=true
fi

# Main execution
main() {
    log "INFO" "Starting ML Platform infrastructure tests"
    log "INFO" "Type: $TEST_TYPE, Environment: $ENVIRONMENT, Parallel: $PARALLEL"
    
    local start_time=$(date +%s)
    
    # Check dependencies
    local deps=("terraform" "kubectl" "kustomize")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required dependency '$cmd' not found"
            exit 1
        fi
    done
    
    # Run tests
    if [[ "$PARALLEL" == "true" ]]; then
        run_tests_parallel
    else
        run_tests_sequential
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Generate reports
    generate_test_report
    print_summary
    
    log "INFO" "Total test execution time: ${total_duration}s"
    
    # Exit with appropriate code
    local failed_count=0
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == "FAILED" ]]; then
            ((failed_count++))
        fi
    done
    
    exit $failed_count
}

main "$@"