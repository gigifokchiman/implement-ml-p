#!/bin/bash
# Parallel test execution runner for infrastructure testing
# Optimizes test execution through intelligent parallelization

# Guard against multiple sourcing
if [[ -n "${_PARALLEL_RUNNER_SH_LOADED:-}" ]]; then
    return 0
fi
_PARALLEL_RUNNER_SH_LOADED=1

set -euo pipefail

# Source common utilities
PARALLEL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PARALLEL_SCRIPT_DIR/../lib/utils/common.sh"
source "$PARALLEL_SCRIPT_DIR/../lib/config/config-loader.sh"

# Global configuration
MAX_PARALLEL_JOBS=4
ENVIRONMENT="local"
CONFIG_FILE=""
VERBOSE=false

# Track running jobs (using arrays for compatibility)
RUNNING_JOBS=()
JOB_NAMES=""
JOB_RESULTS=""

# Cleanup function for background jobs
cleanup_jobs() {
    if [[ ${#RUNNING_JOBS[@]} -gt 0 ]]; then
        print_info "Cleaning up background jobs..."
        for job_pid in "${RUNNING_JOBS[@]}"; do
            if kill -0 "$job_pid" 2>/dev/null; then
                kill "$job_pid" 2>/dev/null || true
            fi
        done
        wait 2>/dev/null || true
    fi
}

# Set up cleanup trap
trap cleanup_jobs EXIT

# Wait for job completion and record results
wait_for_job() {
    local job_pid="$1"
    local job_name="${JOB_NAMES[$job_pid]}"
    
    if wait "$job_pid"; then
        JOB_RESULTS[$job_name]="PASSED"
        print_success "$job_name completed successfully"
    else
        JOB_RESULTS[$job_name]="FAILED"
        print_error "$job_name failed"
    fi
    
    # Remove from running jobs array
    for i in "${!RUNNING_JOBS[@]}"; do
        if [[ "${RUNNING_JOBS[i]}" == "$job_pid" ]]; then
            unset "RUNNING_JOBS[i]"
            break
        fi
    done
}

# Start a background job
start_job() {
    local job_name="$1"
    local job_command="$2"
    local log_file="${3:-/tmp/test-${job_name//\//-}.log}"
    
    print_info "Starting job: $job_name"
    
    # Create log file
    touch "$log_file"
    
    # Start job in background
    (
        if [[ "$VERBOSE" == "true" ]]; then
            eval "$job_command" 2>&1 | tee "$log_file"
        else
            eval "$job_command" > "$log_file" 2>&1
        fi
    ) &
    
    local job_pid=$!
    RUNNING_JOBS+=("$job_pid")
    JOB_NAMES[$job_pid]="$job_name"
    
    print_info "Job $job_name started with PID $job_pid (log: $log_file)"
}

# Wait for any job to complete (returns when first job finishes)
wait_for_any_job() {
    if [[ ${#RUNNING_JOBS[@]} -eq 0 ]]; then
        return 1
    fi
    
    # Wait for any job to complete
    local completed_pid
    completed_pid=$(wait -n "${RUNNING_JOBS[@]}" && echo $! || echo $!)
    
    wait_for_job "$completed_pid"
}

# Wait for all jobs to complete
wait_for_all_jobs() {
    while [[ ${#RUNNING_JOBS[@]} -gt 0 ]]; do
        wait_for_any_job
    done
}

# Manage job queue to respect max parallel limit
manage_job_queue() {
    while [[ ${#RUNNING_JOBS[@]} -ge $MAX_PARALLEL_JOBS ]]; do
        wait_for_any_job
    done
}

# Parallel Terraform validation across environments
run_terraform_validation_parallel() {
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    
    print_header "Running Terraform Validation (Parallel)"
    
    local environments=("local" "dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        manage_job_queue
        
        local env_dir="$terraform_dir/environments/$env"
        if [[ -d "$env_dir" ]]; then
            local job_command="cd '$env_dir' && terraform init -backend=false >/dev/null && terraform validate"
            start_job "terraform-validate-$env" "$job_command"
        else
            print_warning "Environment directory not found: $env_dir"
        fi
    done
    
    wait_for_all_jobs
    print_success "Terraform validation completed"
}

# Parallel Kubernetes validation across overlays
run_kubernetes_validation_parallel() {
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    
    print_header "Running Kubernetes Validation (Parallel)"
    
    local overlays=("local" "dev" "staging" "prod")
    
    for overlay in "${overlays[@]}"; do
        manage_job_queue
        
        local overlay_dir="$kubernetes_dir/overlays/$overlay"
        if [[ -d "$overlay_dir" ]]; then
            local temp_file="/tmp/k8s-${overlay}-$$.yaml"
            local job_command="kustomize build '$overlay_dir' | kubeconform -summary -output json -schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' - > '$temp_file'"
            start_job "k8s-validate-$overlay" "$job_command"
        else
            print_warning "Overlay directory not found: $overlay_dir"
        fi
    done
    
    wait_for_all_jobs
    print_success "Kubernetes validation completed"
}

# Parallel security scanning with multiple tools
run_security_scanning_parallel() {
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    
    print_header "Running Security Scanning (Parallel)"
    
    # Load configuration for current environment
    local config_file="/tmp/infra-test-config-${ENVIRONMENT}.yaml"
    load_config "$ENVIRONMENT" "$config_file"
    
    # Generate tool-specific configurations
    generate_checkov_config "$ENVIRONMENT" "$config_file" "/tmp/checkov-${ENVIRONMENT}.yaml"
    # Generate trivy config to replace tfsec functionality
    generate_security_tool_config "$ENVIRONMENT" "trivy" "/tmp/trivy-${ENVIRONMENT}.yaml"
    
    # Run checkov in background
    manage_job_queue
    local checkov_cmd="checkov --config-file /tmp/checkov-${ENVIRONMENT}.yaml -d '$terraform_dir'"
    start_job "security-checkov" "$checkov_cmd"
    
    # Run trivy config scan in background (replacing tfsec)
    manage_job_queue
    local trivy_config_cmd="trivy config '$terraform_dir' --format json --severity CRITICAL,HIGH"
    start_job "security-trivy-config" "$trivy_config_cmd"
    
    
    wait_for_all_jobs
    print_success "Security scanning completed"
}

# Parallel OPA policy testing
run_opa_policy_parallel() {
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    local policies_dir="$kubernetes_dir/policies"
    
    print_header "Running OPA Policy Tests (Parallel)"
    
    if [[ ! -d "$policies_dir" ]]; then
        print_warning "Policies directory not found: $policies_dir"
        return 0
    fi
    
    local overlays=("local" "dev" "staging" "prod")
    
    for overlay in "${overlays[@]}"; do
        manage_job_queue
        
        local overlay_dir="$kubernetes_dir/overlays/$overlay"
        if [[ -d "$overlay_dir" ]]; then
            local temp_manifest="/tmp/k8s-opa-${overlay}-$$.yaml"
            local job_command="kustomize build '$overlay_dir' > '$temp_manifest' && opa eval -d '$policies_dir' -i '$temp_manifest' 'data.kubernetes.security.deny[x]' | jq -e '.result[0].expressions[0].value | length == 0' >/dev/null"
            start_job "opa-policy-$overlay" "$job_command"
        fi
    done
    
    wait_for_all_jobs
    print_success "OPA policy testing completed"
}

# Static analysis tests (can run in parallel)
run_static_tests_parallel() {
    print_header "Running Static Analysis Tests (Parallel)"
    
    # Terraform format check
    manage_job_queue
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    local fmt_cmd="cd '$terraform_dir' && terraform fmt -check -recursive"
    start_job "terraform-fmt" "$fmt_cmd"
    
    # Kubernetes validation
    run_kubernetes_validation_parallel &
    local k8s_pid=$!
    
    # Terraform validation
    run_terraform_validation_parallel &
    local tf_pid=$!
    
    # Wait for kubernetes and terraform validation
    wait "$k8s_pid" "$tf_pid"
    
    wait_for_all_jobs
    print_success "Static analysis completed"
}

# Unit tests (can run in parallel)
run_unit_tests_parallel() {
    print_header "Running Unit Tests (Parallel)"
    
    # Terraform unit tests
    manage_job_queue
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    local tf_unit_cmd="cd '$terraform_dir' && terraform test -test-directory=../tests/terraform/unit"
    start_job "terraform-unit" "$tf_unit_cmd"
    
    # OPA policy tests
    manage_job_queue
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    local policies_dir="$kubernetes_dir/policies"
    if [[ -d "$policies_dir" ]]; then
        local opa_cmd="opa test '$policies_dir' -v"
        start_job "opa-unit" "$opa_cmd"
    fi
    
    wait_for_all_jobs
    print_success "Unit tests completed"
}

# Print job results summary
print_job_results() {
    print_header "Job Results Summary"
    
    local total_jobs=0
    local passed_jobs=0
    local failed_jobs=0
    
    for job_name in "${!JOB_RESULTS[@]}"; do
        ((total_jobs++))
        local result="${JOB_RESULTS[$job_name]}"
        
        if [[ "$result" == "PASSED" ]]; then
            ((passed_jobs++))
            print_success "$job_name: PASSED"
        else
            ((failed_jobs++))
            print_error "$job_name: FAILED"
        fi
    done
    
    echo ""
    echo "Summary: $passed_jobs passed, $failed_jobs failed out of $total_jobs total jobs"
    
    if [[ $failed_jobs -gt 0 ]]; then
        print_error "Some jobs failed. Check logs for details."
        return 1
    else
        print_success "All jobs completed successfully!"
        return 0
    fi
}

# Parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -j|--jobs)
                MAX_PARALLEL_JOBS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
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

Parallel test execution runner for infrastructure testing.

OPTIONS:
  -e, --environment ENV    Target environment (default: local)
  -j, --jobs N            Maximum parallel jobs (default: 4)
  -v, --verbose           Verbose output
  -c, --config FILE       Configuration file
  -h, --help              Show this help

COMMANDS:
  static                  Run static analysis tests in parallel
  unit                    Run unit tests in parallel
  security                Run security scans in parallel
  terraform               Run Terraform validation in parallel
  kubernetes              Run Kubernetes validation in parallel
  opa                     Run OPA policy tests in parallel
  all                     Run all test types in parallel

EXAMPLES:
  $0 static                              # Run static tests
  $0 --environment prod security         # Run security scans for production
  $0 --jobs 8 --verbose all             # Run all tests with 8 parallel jobs
  
EOF
}

# Main function
main() {
    # Set up cleanup
    setup_cleanup_trap
    
    # Parse options
    parse_options "$@"
    
    # Get command
    local command="${!#}"
    
    print_info "Parallel Test Runner"
    print_info "Environment: $ENVIRONMENT"
    print_info "Max parallel jobs: $MAX_PARALLEL_JOBS"
    print_info "Command: $command"
    echo ""
    
    case "$command" in
        "static")
            run_static_tests_parallel
            ;;
        "unit")
            run_unit_tests_parallel
            ;;
        "security")
            run_security_scanning_parallel
            ;;
        "terraform")
            run_terraform_validation_parallel
            ;;
        "kubernetes")
            run_kubernetes_validation_parallel
            ;;
        "opa")
            run_opa_policy_parallel
            ;;
        "all")
            run_static_tests_parallel
            run_unit_tests_parallel
            run_security_scanning_parallel
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
    
    # Print results
    print_job_results
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi