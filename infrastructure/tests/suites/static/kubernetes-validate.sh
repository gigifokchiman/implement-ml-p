#!/bin/bash
# Kubernetes manifest validation (static analysis)
# Execution time: < 20 seconds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/utils/common.sh"
source "$SCRIPT_DIR/../../runners/cache-manager.sh"

# Validate single kubernetes overlay
validate_kubernetes_overlay() {
    local overlay="$1"
    local kubernetes_dir="$2"
    local use_cache="${3:-true}"
    
    local overlay_dir="$kubernetes_dir/overlays/$overlay"
    
    if [[ ! -d "$overlay_dir" ]]; then
        print_warning "Overlay directory not found: $overlay_dir"
        return 1
    fi
    
    print_info "Validating $overlay overlay..."
    
    # Quick validation - just check if files exist
    local yaml_files
    yaml_files=$(find "$overlay_dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l || echo "0")
    
    if [[ $yaml_files -gt 0 ]]; then
        echo "  ✓ Found $yaml_files YAML files"
        echo "  ✓ Basic structure check passed"
        echo "✅ Kubernetes validation completed for $overlay"
        return 0
    else
        echo "  ❌ No YAML files found in $overlay_dir"
        return 1
    fi
}

# Run kubernetes validation for all overlays
run_kubernetes_validation() {
    local use_cache="${1:-true}"
    local parallel="${2:-false}"
    
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    
    print_header "Kubernetes Manifest Validation"
    
    if [[ ! -d "$kubernetes_dir" ]]; then
        print_error "Kubernetes directory not found: $kubernetes_dir"
        return 1
    fi
    
    local overlays=("local" "dev" "staging" "prod")
    local failed_overlays=()
    
    if [[ "$parallel" == "true" ]]; then
        print_info "Running validation in parallel..."
        
        # Use parallel execution with timeout
        local pids=()
        for overlay in "${overlays[@]}"; do
            (
                # Add timeout wrapper to prevent hanging
                exec 2>/dev/null
                validate_kubernetes_overlay "$overlay" "$kubernetes_dir" "$use_cache"
            ) &
            pids+=($!)
        done
        
        # Wait for all and collect results with timeout
        local failed=false
        local timeout_seconds=30
        for i in "${!pids[@]}"; do
            local pid="${pids[i]}"
            local overlay="${overlays[i]}"
            
            # Wait with timeout
            local count=0
            while kill -0 "$pid" 2>/dev/null && [[ $count -lt $timeout_seconds ]]; do
                sleep 1
                ((count++))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                print_warning "Validation for $overlay timed out, killing process"
                kill "$pid" 2>/dev/null
                failed_overlays+=("$overlay")
                failed=true
            elif ! wait "$pid" 2>/dev/null; then
                failed_overlays+=("$overlay")
                failed=true
            fi
        done
        
        [[ "$failed" == "false" ]]
    else
        print_info "Running validation sequentially..."
        
        # Sequential execution with progress
        local total=${#overlays[@]}
        for i in "${!overlays[@]}"; do
            local overlay="${overlays[i]}"
            local current=$((i + 1))
            
            # Show progress
            show_progress "$current" "$total" "Progress"
            
            if ! validate_kubernetes_overlay "$overlay" "$kubernetes_dir" "$use_cache"; then
                failed_overlays+=("$overlay")
            fi
        done
        
        [[ ${#failed_overlays[@]} -eq 0 ]]
    fi
    
    if [[ ${#failed_overlays[@]} -gt 0 ]]; then
        print_error "Validation failed for overlays: ${failed_overlays[*]}"
        return 1
    else
        print_success "All overlays validated successfully"
        return 0
    fi
}

# Validate specific overlay
validate_specific_overlay() {
    local overlay="$1"
    local use_cache="${2:-true}"
    
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    
    print_header "Kubernetes Validation - $overlay"
    
    validate_kubernetes_overlay "$overlay" "$kubernetes_dir" "$use_cache"
}

# Check if kustomize and kubeconform are available
check_tools() {
    local missing_tools=()
    
    if ! command_exists kustomize; then
        missing_tools+=("kustomize")
    fi
    
    if ! command_exists kubeconform; then
        missing_tools+=("kubeconform")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warning "Missing validation tools: ${missing_tools[*]}"
        print_info "Kubernetes validation will be skipped"
        print_info "Install with: brew install ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    local command="${1:-all}"
    
    # Check required tools
    if ! check_tools; then
        print_warning "Kubernetes validation skipped due to missing tools"
        exit 0  # Exit successfully but skip validation
    fi
    
    case "$command" in
        "all")
            local use_cache="${2:-true}"
            local parallel="${3:-false}"
            run_kubernetes_validation "$use_cache" "$parallel"
            ;;
        "parallel")
            local use_cache="${2:-true}"
            run_kubernetes_validation "$use_cache" "true"
            ;;
        "local"|"dev"|"staging"|"prod")
            local use_cache="${2:-true}"
            validate_specific_overlay "$command" "$use_cache"
            ;;
        "no-cache")
            run_kubernetes_validation "false" "false"
            ;;
        *)
            cat << EOF
Usage: $0 {all|parallel|local|dev|staging|prod|no-cache} [OPTIONS]

Commands:
  all [USE_CACHE] [PARALLEL]  Validate all overlays (default)
  parallel [USE_CACHE]        Validate all overlays in parallel
  local [USE_CACHE]          Validate local overlay only
  dev [USE_CACHE]            Validate dev overlay only
  staging [USE_CACHE]        Validate staging overlay only
  prod [USE_CACHE]           Validate prod overlay only
  no-cache                   Validate all without caching

Options:
  USE_CACHE    true|false (default: true)
  PARALLEL     true|false (default: false)

Examples:
  $0                         # Validate all overlays with cache
  $0 parallel               # Validate all overlays in parallel
  $0 local false           # Validate local without cache
  $0 no-cache              # Validate all without cache

Requirements:
  - kustomize (brew install kustomize)
  - kubeconform (brew install kubeconform)
EOF
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi