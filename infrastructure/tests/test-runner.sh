#!/bin/bash
# Unified Test Orchestrator for Infrastructure Testing
# Single entry point for all test execution with optimized performance

set -euo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils/common.sh"
source "$SCRIPT_DIR/lib/config/config-loader.sh"
source "$SCRIPT_DIR/lib/tools/tool-manager.sh"
source "$SCRIPT_DIR/runners/parallel-runner-simple.sh"
source "$SCRIPT_DIR/runners/cache-manager.sh"

# Global configuration
ENVIRONMENT="local"
USE_CACHE=false  # Disable cache to prevent hanging
USE_PARALLEL=false  # Disable parallel by default to prevent hanging
VERBOSE=false
FAIL_FAST=false
DRY_RUN=false
CLEAN_CACHE=false

# Detect if running in Docker and adjust settings
if [[ -f /.dockerenv ]] || [[ -n "${DOCKER_CONTAINER:-}" ]] || [[ -n "${container:-}" ]]; then
    export DOCKER_ENV=true
    USE_PARALLEL=false  # Force disable parallel in Docker
    print_info "Docker environment detected - using sequential execution" >/dev/null 2>&1 || true
else
    export DOCKER_ENV=false
fi

# Valid environments and commands
VALID_ENVIRONMENTS=("local" "dev" "staging" "prod")
VALID_COMMANDS=("all" "static" "security" "unit" "integration" "performance" "status" "install" "clean-cache")

# Validation functions
validate_environment() {
    local env="$1"
    for valid_env in "${VALID_ENVIRONMENTS[@]}"; do
        if [[ "$env" == "$valid_env" ]]; then
            return 0
        fi
    done
    print_error "Invalid environment: $env"
    print_info "Valid environments: ${VALID_ENVIRONMENTS[*]}"
    return 1
}

validate_command() {
    local cmd="$1"
    for valid_cmd in "${VALID_COMMANDS[@]}"; do
        if [[ "$cmd" == "$valid_cmd" ]]; then
            return 0
        fi
    done
    print_error "Invalid command: $cmd"
    print_info "Valid commands: ${VALID_COMMANDS[*]}"
    return 1
}

validate_script_path() {
    local script_path="$1"
    # Ensure script path is within the expected directory structure
    if [[ ! "$script_path" =~ ^"$SCRIPT_DIR"/.* ]]; then
        print_error "Script path outside allowed directory: $script_path"
        return 1
    fi
    if [[ ! -f "$script_path" ]]; then
        print_error "Script not found: $script_path"
        return 1
    fi
    if [[ ! -x "$script_path" ]]; then
        print_error "Script not executable: $script_path"
        return 1
    fi
    return 0
}

# Test suite descriptions (using function for compatibility)
get_test_suite_description() {
    local suite="$1"
    case "$suite" in
        "static") echo "Static Analysis (< 30s)" ;;
        "security") echo "Security Scanning (< 2m)" ;;
        "unit") echo "Unit Testing (< 5m)" ;;
        "integration") echo "Integration Testing (15-30m)" ;;
        "performance") echo "Performance Testing (variable)" ;;
        *) echo "Unknown test suite" ;;
    esac
}

# Initialize test orchestrator
init_orchestrator() {
    print_header "Infrastructure Test Orchestrator"
    print_info "Environment: $ENVIRONMENT"
    print_info "Cache: $([ "$USE_CACHE" == "true" ] && echo "enabled" || echo "disabled")"
    print_info "Parallel: $([ "$USE_PARALLEL" == "true" ] && echo "enabled" || echo "disabled")"
    print_info "Verbose: $([ "$VERBOSE" == "true" ] && echo "enabled" || echo "disabled")"
    echo ""

    # Initialize cache if enabled
    if [[ "$USE_CACHE" == "true" ]]; then
        init_cache

        if [[ "$CLEAN_CACHE" == "true" ]]; then
            print_info "Cleaning expired cache entries..."
            clean_expired_cache
        fi
    fi

    # Set up cleanup
    setup_cleanup_trap
}

# Run static analysis tests
run_static_tests() {
    print_header "Static Analysis Tests"

    local failed_tests=()
    local test_start_time
    test_start_time=$(date +%s)

    # Force sequential execution in Docker environments
    local actual_parallel="$USE_PARALLEL"
    if [[ "$DOCKER_ENV" == "true" ]]; then
        actual_parallel="false"
        print_info "Docker environment - forcing sequential execution for static tests"
    fi

    if [[ "$actual_parallel" == "true" ]]; then
        print_info "Running static tests in parallel..."
        echo -n "  ◦ Initializing parallel execution... "
        sleep 0.5
        echo "✓"

        # Start background jobs
        local pids=()
        local test_names=()

        # Terraform format check
        local tf_fmt_script="$SCRIPT_DIR/suites/static/terraform-fmt.sh"
        if validate_script_path "$tf_fmt_script"; then
            "$tf_fmt_script" check &
            pids+=($!)
            test_names+=("terraform-fmt")
        fi

        # Terraform validation (parallel environments)
        local tf_validate_script="$SCRIPT_DIR/suites/static/terraform-validate.sh"
        if validate_script_path "$tf_validate_script"; then
            "$tf_validate_script" parallel "$USE_CACHE" &
            pids+=($!)
            test_names+=("terraform-validate")
        fi

        # Kubernetes validation (parallel overlays)
        local k8s_validate_script="$SCRIPT_DIR/suites/static/kubernetes-validate.sh"
        if validate_script_path "$k8s_validate_script"; then
            "$k8s_validate_script" parallel "$USE_CACHE" &
            pids+=($!)
            test_names+=("kubernetes-validate")
        fi

        # Wait for all jobs and collect results
        for i in "${!pids[@]}"; do
            if wait "${pids[i]}"; then
                record_test_result "${test_names[i]}" 0
            else
                record_test_result "${test_names[i]}" 1
                failed_tests+=("${test_names[i]}")

                if [[ "$FAIL_FAST" == "true" ]]; then
                    print_error "Failing fast due to ${test_names[i]} failure"
                    break
                fi
            fi
        done
    else
        print_info "Running static tests sequentially..."

        # Sequential execution
        local tf_fmt_script="$SCRIPT_DIR/suites/static/terraform-fmt.sh"
        if validate_script_path "$tf_fmt_script" && "$tf_fmt_script" check; then
            record_test_result "terraform-fmt" 0
        else
            record_test_result "terraform-fmt" 1
            failed_tests+=("terraform-fmt")
            if [[ "$FAIL_FAST" == "true" ]]; then
                print_error "Failing fast due to terraform-fmt failure"
                return 1
            fi
        fi

        local tf_validate_script="$SCRIPT_DIR/suites/static/terraform-validate.sh"
        if validate_script_path "$tf_validate_script" && "$tf_validate_script" all "$USE_CACHE"; then
            record_test_result "terraform-validate" 0
        else
            record_test_result "terraform-validate" 1
            failed_tests+=("terraform-validate")
            if [[ "$FAIL_FAST" == "true" ]]; then
                print_error "Failing fast due to terraform-validate failure"
                return 1
            fi
        fi

        local k8s_validate_script="$SCRIPT_DIR/suites/static/kubernetes-validate.sh"
        if validate_script_path "$k8s_validate_script" && "$k8s_validate_script" all "$USE_CACHE"; then
            record_test_result "kubernetes-validate" 0
        else
            record_test_result "kubernetes-validate" 1
            failed_tests+=("kubernetes-validate")
            if [[ "$FAIL_FAST" == "true" ]]; then
                print_error "Failing fast due to kubernetes-validate failure"
                return 1
            fi
        fi
    fi

    local test_end_time
    test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    print_info "Static tests completed in ${test_duration}s"

    [[ ${#failed_tests[@]} -eq 0 ]]
}

# Run security tests
run_security_tests() {
    print_header "Security Tests"

    local failed_tests=()
    local test_start_time
    test_start_time=$(date +%s)

    # Run consolidated security scan (sequential mode for reliability, no cache to avoid issues)
    local security_script="$SCRIPT_DIR/suites/security/security-scan.sh"
    
    # Use sequential execution in Docker or if parallel is disabled
    local scan_mode="no-cache"
    if [[ "$DOCKER_ENV" == "true" ]] || [[ "$USE_PARALLEL" == "false" ]]; then
        scan_mode="sequential"
        print_info "Using sequential security scanning for reliability"
    fi
    
    if validate_script_path "$security_script" && "$security_script" "$scan_mode" "$ENVIRONMENT" "false"; then
        record_test_result "security-scan" 0
    else
        record_test_result "security-scan" 1
        failed_tests+=("security-scan")
    fi
    local test_end_time
    test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    print_info "Security tests completed in ${test_duration}s"

    [[ ${#failed_tests[@]} -eq 0 ]]
}

# Run unit tests
run_unit_tests() {
    print_header "Unit Tests"

    local failed_tests=()
    local test_start_time
    test_start_time=$(date +%s)

    # Force sequential execution in Docker environments
    local actual_parallel="$USE_PARALLEL"
    if [[ "$DOCKER_ENV" == "true" ]]; then
        actual_parallel="false"
        print_info "Docker environment - forcing sequential execution for unit tests"
    fi

    if [[ "$actual_parallel" == "true" ]]; then
        print_info "Running unit tests in parallel..."

        # Start background jobs
        local pids=()
        local test_names=()

        # Terraform unit tests
        local tf_unit_script="$SCRIPT_DIR/suites/unit/terraform-unit.sh"
        if validate_script_path "$tf_unit_script"; then
            "$tf_unit_script" run "" "" "$USE_CACHE" &
            pids+=($!)
            test_names+=("terraform-unit")
        fi

        # OPA policy tests
        local opa_script="$SCRIPT_DIR/suites/unit/opa-policies.sh"
        echo "opa path:"
        echo "$opa_script"
        if validate_script_path "$opa_script"; then
            "$opa_script" test "" "$USE_CACHE" &
            pids+=($!)
            test_names+=("opa-policies")
        fi

        # Wait for all jobs and collect results
        for i in "${!pids[@]}"; do
            if wait "${pids[i]}"; then
                record_test_result "${test_names[i]}" 0
            else
                record_test_result "${test_names[i]}" 1
                failed_tests+=("${test_names[i]}")

                if [[ "$FAIL_FAST" == "true" ]]; then
                    print_error "Failing fast due to ${test_names[i]} failure"
                    break
                fi
            fi
        done
    else
        print_info "Running unit tests sequentially..."

        # Sequential execution
        local tf_unit_script="$SCRIPT_DIR/suites/unit/terraform-unit.sh"
        if validate_script_path "$tf_unit_script" && "$tf_unit_script" run "" "" "$USE_CACHE"; then
            record_test_result "terraform-unit" 0
        else
            record_test_result "terraform-unit" 1
            failed_tests+=("terraform-unit")
            if [[ "$FAIL_FAST" == "true" ]]; then
                print_error "Failing fast due to terraform-unit failure"
                return 1
            fi
        fi

        local opa_script="$SCRIPT_DIR/suites/unit/opa-policies.sh"
        if validate_script_path "$opa_script" && "$opa_script" test "" "$USE_CACHE"; then
            record_test_result "opa-policies" 0
        else
            record_test_result "opa-policies" 1
            failed_tests+=("opa-policies")
            if [[ "$FAIL_FAST" == "true" ]]; then
                print_error "Failing fast due to opa-policies failure"
                return 1
            fi
        fi
    fi

    local test_end_time
    test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    print_info "Unit tests completed in ${test_duration}s"

    [[ ${#failed_tests[@]} -eq 0 ]]
}

# Run integration tests
run_integration_tests() {
    print_header "Integration Tests"

    local failed_tests=()
    local test_start_time
    test_start_time=$(date +%s)

    # Check if cluster is available
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "No Kubernetes cluster found for integration tests"
        print_info "Start a cluster with: make -C .. deploy-local"
        return 1
    fi

    print_info "Running integration tests against live cluster..."

    # OPA policy validation against live manifests
    local opa_script="$SCRIPT_DIR/suites/unit/opa-policies.sh"
    if validate_script_path "$opa_script" && "$opa_script" validate "$ENVIRONMENT" "" false; then
        record_test_result "opa-validation" 0
    else
        record_test_result "opa-validation" 1
        failed_tests+=("opa-validation")
    fi

    # Additional integration tests can be added here
    # - Terraform plan/apply validation
    # - Kubernetes deployment tests
    # - End-to-end workflow tests

    local test_end_time
    test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    print_info "Integration tests completed in ${test_duration}s"

    [[ ${#failed_tests[@]} -eq 0 ]]
}

# Run performance tests
run_performance_tests() {
    print_header "Performance Tests"

    print_warning "Performance tests not yet implemented in refactored structure"
    print_info "See original performance/ directory for K6 and chaos tests"

    # Placeholder for future performance test integration
    # This would include:
    # - K6 load testing
    # - Chaos engineering tests
    # - Resource utilization tests

    return 0
}

# Run specific test suite
run_test_suite() {
    local suite="$1"

    case "$suite" in
        "static")
            run_static_tests
            ;;
        "security")
            run_security_tests
            ;;
        "unit")
            run_unit_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        *)
            print_error "Unknown test suite: $suite"
            return 1
            ;;
    esac
}

# Run all test suites
run_all_tests() {
    local suites_to_run=("static" "security" "unit")
    local start_time
    start_time=$(date +%s)

    # Add integration tests if cluster is available
    if kubectl cluster-info >/dev/null 2>&1; then
        suites_to_run+=("integration")
    else
        print_warning "Skipping integration tests - no cluster available"
    fi

    local failed_suites=()

    for suite in "${suites_to_run[@]}"; do
        print_info "Starting test suite: $suite"

        if run_test_suite "$suite"; then
            print_success "Test suite '$suite' passed"
        else
            print_error "Test suite '$suite' failed"
            failed_suites+=("$suite")

            if [[ "$FAIL_FAST" == "true" ]]; then
                print_error "Failing fast due to $suite failure"
                break
            fi
        fi

        echo ""
    done

    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    print_header "Test Execution Summary"
    print_info "Total execution time: ${total_duration}s"

    if [[ ${#failed_suites[@]} -eq 0 ]]; then
        print_success "All test suites passed!"
        return 0
    else
        print_error "Failed test suites: ${failed_suites[*]}"
        return 1
    fi
}

# Show test status
show_test_status() {
    print_header "Test Environment Status"

    # Tool status
    check_tool_status

    # Cache status
    if [[ "$USE_CACHE" == "true" ]]; then
        echo ""
        show_cache_stats
    fi

    # Configuration status
    echo ""
    print_info "Configuration for environment: $ENVIRONMENT"
    validate_config "$ENVIRONMENT"

    # Cluster status
    echo ""
    if kubectl cluster-info >/dev/null 2>&1; then
        print_success "Kubernetes cluster is available"
        kubectl cluster-info
    else
        print_warning "No Kubernetes cluster available (integration tests will be skipped)"
    fi
}

# Parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                if ! validate_environment "$2"; then
                    exit 1
                fi
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
            -f|--fail-fast)
                FAIL_FAST=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --clean-cache)
                CLEAN_CACHE=true
                shift
                ;;
            --no-cache)
                USE_CACHE=false
                shift
                ;;
            --no-parallel)
                USE_PARALLEL=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Unified test orchestrator for infrastructure testing.

OPTIONS:
  -e, --environment ENV    Target environment (default: local)
  -c, --cache BOOL        Enable/disable caching (default: true)
  -p, --parallel BOOL     Enable/disable parallel execution (default: true)
  -v, --verbose           Verbose output
  -f, --fail-fast         Stop on first failure
  -n, --dry-run           Show what would be executed
  --clean-cache          Clean expired cache entries before running
  --no-cache             Disable caching (same as --cache false)
  --no-parallel          Disable parallel execution (same as --parallel false)
  -h, --help             Show this help

COMMANDS:
  all                    Run all test suites (default)
  static                 Run static analysis tests only
  security               Run security scanning tests only
  unit                   Run unit tests only
  integration            Run integration tests only
  performance            Run performance tests only
  status                 Show test environment status
  install                Install required tools
  clean-cache            Clean all cache entries

TEST SUITES:
EOF

    local suites=("static" "security" "unit" "integration" "performance")
    for suite in "${suites[@]}"; do
        printf "  %-12s %s\n" "$suite" "$(get_test_suite_description "$suite")"
    done

    cat << EOF

EXAMPLES:
  $0                                    # Run all tests with defaults
  $0 --environment prod security        # Run security tests for production
  $0 --no-cache --verbose all          # Run all tests without cache, verbose
  $0 --fail-fast static unit           # Run static and unit tests, stop on first failure
  $0 status                            # Show test environment status

ENVIRONMENTS:
  local       Local development (relaxed security)
  dev         Development environment (moderate security)
  staging     Staging environment (strict security)
  prod        Production environment (strictest security)

EOF
}

# Main function
main() {
    # Reset test counters
    PASSED_TESTS=0
    FAILED_TESTS=0

    # Parse options
    parse_options "$@"

    # Get command
    local command="${!#:-all}"

    # Validate command
    if ! validate_command "$command"; then
        exit 1
    fi

    # Initialize orchestrator
    init_orchestrator

    # Handle dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN - would execute: $command"
        print_info "Environment: $ENVIRONMENT"
        print_info "Cache: $USE_CACHE"
        print_info "Parallel: $USE_PARALLEL"
        return 0
    fi

    # Execute command
    case "$command" in
        "all")
            run_all_tests
            ;;
        "static")
            run_test_suite "static"
            ;;
        "security")
            run_test_suite "security"
            ;;
        "unit")
            run_test_suite "unit"
            ;;
        "integration")
            run_test_suite "integration"
            ;;
        "performance")
            run_test_suite "performance"
            ;;
        "status")
            show_test_status
            ;;
        "install")
            install_all_tools
            ;;
        "clean-cache")
            clear_cache
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac

    # Print final summary
    if [[ "$command" != "status" && "$command" != "install" && "$command" != "clean-cache" ]]; then
        echo ""
        print_test_summary
    fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
