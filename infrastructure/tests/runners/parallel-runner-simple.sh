#!/bin/bash
# Simplified parallel test execution for compatibility
# Works with older bash versions

# Guard against multiple sourcing
if [[ -n "${_PARALLEL_RUNNER_SIMPLE_SH_LOADED:-}" ]]; then
    return 0
fi
_PARALLEL_RUNNER_SIMPLE_SH_LOADED=1

set -euo pipefail

# Source common utilities
PARALLEL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PARALLEL_SCRIPT_DIR/../lib/utils/common.sh"

# Simple parallel execution functions
run_in_parallel() {
    local commands=("$@")
    local pids=()
    local failed=false
    
    # Start all commands in background
    for cmd in "${commands[@]}"; do
        eval "$cmd" &
        pids+=($!)
    done
    
    # Wait for all to complete
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed=true
        fi
    done
    
    [[ "$failed" == "false" ]]
}

# Run terraform validation in parallel
run_terraform_validation_parallel() {
    local terraform_dir
    terraform_dir=$(get_terraform_dir)
    
    print_header "Running Terraform Validation (Parallel)"
    
    local commands=()
    local environments=("local" "dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        local env_dir="$terraform_dir/environments/$env"
        if [[ -d "$env_dir" ]]; then
            commands+=("cd '$env_dir' && terraform init -backend=false >/dev/null && terraform validate")
        fi
    done
    
    if run_in_parallel "${commands[@]}"; then
        print_success "Terraform validation completed"
        return 0
    else
        print_error "Terraform validation failed"
        return 1
    fi
}

# Run kubernetes validation in parallel
run_kubernetes_validation_parallel() {
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    
    print_header "Running Kubernetes Validation (Parallel)"
    
    local commands=()
    local overlays=("local" "dev" "staging" "prod")
    
    for overlay in "${overlays[@]}"; do
        local overlay_dir="$kubernetes_dir/overlays/$overlay"
        if [[ -d "$overlay_dir" ]]; then
            commands+=("kustomize build '$overlay_dir' | kubeconform -summary -output json -schema-location default -")
        fi
    done
    
    if run_in_parallel "${commands[@]}"; then
        print_success "Kubernetes validation completed"
        return 0
    else
        print_error "Kubernetes validation failed"
        return 1
    fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a library file. Source it instead of executing directly."
    exit 1
fi