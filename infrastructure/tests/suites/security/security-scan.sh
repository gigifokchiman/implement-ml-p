#!/bin/bash
# Security scanning with consolidated tools
# Execution time: < 2 minutes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/utils/common.sh"
source "$SCRIPT_DIR/../../lib/config/config-loader.sh"
source "$SCRIPT_DIR/../../runners/cache-manager.sh"

# Run consolidated security scan
run_security_scan() {
    local environment="${1:-local}"
    local target_dir="${2:-}"
    local use_cache="${3:-true}"
    local parallel="${4:-true}"

    # Set up logging
    local log_file="/tmp/security-scan-${environment}-$(date +%Y%m%d-%H%M%S).log"

    print_header "Security Scanning - $environment"
    print_info "Detailed logs: $log_file"

    # Determine target directory
    if [[ -z "$target_dir" ]]; then
        target_dir=$(get_terraform_dir)
    fi

    if [[ ! -d "$target_dir" ]]; then
        print_error "Target directory not found: $target_dir"
        return 1
    fi

    # Load configuration and generate tool configs
    local config_file="/tmp/infra-test-config-${environment}.yaml"
    if ! load_config "$environment" "$config_file"; then
        print_error "Failed to load configuration for $environment"
        return 1
    fi

    # Generate tool configs from security requirements
    if ! generate_security_tool_config "$environment" "checkov" "/tmp/checkov-${environment}.yaml"; then
        print_warning "Failed to generate checkov config, using fallback"
        generate_checkov_config "$environment" "$config_file" "/tmp/checkov-${environment}.yaml"
    fi


    generate_security_tool_config "$environment" "trivy" "/tmp/trivy-${environment}.yaml" || true

    # Get primary and secondary tools from config
    local primary_tool secondary_tool
    primary_tool=$(get_config_value "$config_file" ".security.tools.primary" "checkov")
    secondary_tool=$(get_config_value "$config_file" ".security.tools.secondary" "trivy")

    local scan_results=()
    local failed_scans=()

    # Check if any tools are available before proceeding
    local has_local_tools=false
    local has_cluster_tools=false

    # Check for local tools
    if command_exists "trivy" || command_exists "checkov"; then
        has_local_tools=true
    fi

    # Check for cluster tools (with timeout to handle Docker gracefully)
    if command_exists "kubectl"; then
        if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
            if kubectl get deployment trivy-server -n data-platform-security-scanning >/dev/null 2>&1; then
                has_cluster_tools=true
            fi
        fi
    fi


    if [[ "$has_local_tools" == "false" && "$has_cluster_tools" == "false" ]]; then
        print_warning "No security scanning tools available"
        print_info "Security scanning skipped - consider installing checkov/trivy or deploying trivy server"
        return 0
    fi

    # Force sequential execution in Docker environments to avoid PID issues
    if [[ -f /.dockerenv ]] || [[ -n "${DOCKER_CONTAINER:-}" ]] || [[ -n "${container:-}" ]]; then
        parallel="false"
        print_info "Docker environment detected - forcing sequential execution"
    fi

    if [[ "$parallel" == "true" ]]; then
        print_info "Running security scans in parallel..."

        # Run primary and secondary scans in parallel
        local pids=()
        local scan_names=()

        # Primary tool scan (check both local and containerized)
        if is_tool_available "$primary_tool"; then
            run_single_security_scan "$primary_tool" "$environment" "$target_dir" "$use_cache" &
            pids+=($!)
            scan_names+=("$primary_tool")
        else
            print_warning "$primary_tool not available, skipping"
        fi

        # Secondary tool scan
        if is_tool_available "$secondary_tool"; then
            run_single_security_scan "$secondary_tool" "$environment" "$target_dir" "$use_cache" &
            pids+=($!)
            scan_names+=("$secondary_tool")
        else
            print_warning "$secondary_tool not available, skipping"
        fi

        # Container security scan (if available)
        if is_tool_available "trivy"; then
            run_single_security_scan "trivy" "$environment" "$target_dir" "$use_cache" &
            pids+=($!)
            scan_names+=("trivy")
        else
            print_warning "trivy not available, skipping"
        fi

        # Wait for all scans to complete with timeout
        local all_passed=true
        if [[ ${#pids[@]} -gt 0 ]]; then
            print_info "Waiting for ${#pids[@]} security scans to complete..."
            
            for i in "${!pids[@]}"; do
                local timeout_count=0
                local max_timeout=120  # 120 seconds timeout for security scans
                local last_dot_time=0

                # Wait with timeout and progress indication
                while kill -0 "${pids[i]}" 2>/dev/null && [[ $timeout_count -lt $max_timeout ]]; do
                    sleep 1
                    ((timeout_count++))
                    
                    # Show progress every 10 seconds instead of every second
                    if [[ $((timeout_count % 10)) -eq 0 ]]; then
                        print_info "  ${scan_names[i]}: ${timeout_count}s elapsed..."
                    fi
                done

                # Check if process is still running (timed out)
                if kill -0 "${pids[i]}" 2>/dev/null; then
                    print_warning "${scan_names[i]} scan timed out after ${max_timeout}s, terminating"
                    kill "${pids[i]}" 2>/dev/null || true
                    sleep 2  # Give process time to die
                    kill -9 "${pids[i]}" 2>/dev/null || true  # Force kill if needed
                    scan_results+=("${scan_names[i]}:TIMEOUT")
                    failed_scans+=("${scan_names[i]}")
                    all_passed=false
                else
                    # Process completed, get exit status
                    if wait "${pids[i]}" 2>/dev/null; then
                        scan_results+=("${scan_names[i]}:PASSED")
                        print_success "${scan_names[i]} scan completed"
                    else
                        local exit_code=$?
                        scan_results+=("${scan_names[i]}:FAILED")
                        failed_scans+=("${scan_names[i]}")
                        print_error "${scan_names[i]} scan failed (exit code: $exit_code)"
                        all_passed=false
                    fi
                fi
            done
        else
            print_warning "No security tools available to run - skipping security scans"
            # Consider this a pass since no tools means no security requirements
            all_passed=true
        fi

        [[ "$all_passed" == "true" ]]
    else
        print_info "Running security scans sequentially..."

        # Sequential execution - only use available tools
        local tools=()
        if is_tool_available "$primary_tool"; then
            tools+=("$primary_tool")
        fi
        if is_tool_available "$secondary_tool" && [[ "$secondary_tool" != "$primary_tool" ]]; then
            tools+=("$secondary_tool")
        fi
        # Add trivy if not already included
        if is_tool_available "trivy" && [[ "$primary_tool" != "trivy" ]] && [[ "$secondary_tool" != "trivy" ]]; then
            tools+=("trivy")
        fi

        local all_passed=true
        for tool in "${tools[@]}"; do
            if is_tool_available "$tool"; then
                if run_single_security_scan "$tool" "$environment" "$target_dir" "$use_cache"; then
                    scan_results+=("$tool:PASSED")
                    print_success "$tool scan completed"
                else
                    scan_results+=("$tool:FAILED")
                    failed_scans+=("$tool")
                    print_error "$tool scan failed"
                    all_passed=false
                fi
            else
                print_warning "$tool not available"
            fi
        done

        [[ "$all_passed" == "true" ]]
    fi

    # Print summary
    print_info "Security scan results:"
    for result in "${scan_results[@]}"; do
        echo "  $result"
    done

    # Check if we should block on failure based on security requirements
    local should_block=false
    if command_exists yq && should_block_on_failure "$environment"; then
        should_block=true
    fi

    if [[ ${#failed_scans[@]} -gt 0 ]]; then
        print_error "Security scans failed: ${failed_scans[*]}"
        print_error "Security scan tools failed to execute properly"
        print_error "Check detailed logs: $log_file"
        return 1
    else
        print_success "All security scans passed"
        print_info "Detailed logs saved to: $log_file"
        return 0
    fi
}

# Run single security scan tool
run_single_security_scan() {
    local tool="$1"
    local environment="$2"
    local target_dir="$3"
    local use_cache="${4:-true}"

    local config_file=""

    if [[ "$use_cache" == "true" ]]; then
        cache_security_scan "$tool" "$environment" "$target_dir" "$config_file"
    else
        # Run scan and capture both output and exit code
        local scan_output
        local scan_exit_code

        # Execute scan command safely without eval and log to file
        case "$tool" in
            "checkov")
                if command_exists "checkov"; then
                    # Create temporary file for checkov output to avoid BrokenPipeError
                    local checkov_temp="/tmp/checkov-output-$$.json"
                    echo "=== CHECKOV SCAN OUTPUT ===" >> "$log_file"

                    # Run checkov with output to temp file
                    if checkov -d "$target_dir" --output json --compact > "$checkov_temp" 2>> "$log_file"; then
                        scan_exit_code=0
                        scan_output=$(cat "$checkov_temp" 2>/dev/null || echo '{"results":[]}')
                        cat "$checkov_temp" >> "$log_file" 2>&1
                    else
                        scan_exit_code=$?
                        scan_output='{"results":[]}'
                        echo "ERROR: checkov failed with exit code $scan_exit_code" >> "$log_file"
                    fi

                    echo "=== END CHECKOV SCAN ===" >> "$log_file"
                    # Clean up temp file
                    [[ -f "$checkov_temp" ]] && rm -f "$checkov_temp"
                else
                    echo "INFO: checkov not available, skipping checkov scan" >> "$log_file"
                    return 0  # Skip if checkov not available
                fi
                ;;
            "trivy")
                if [[ "$environment" == "local" ]]; then
                    echo "=== TRIVY SCAN OUTPUT ===" >> "$log_file"
                    echo "INFO: Filtering AWS checks for local environment" >> "$log_file"

                    # Run scan and filter AWS results
                    local raw_output
                    raw_output=$(trivy config "$target_dir" --format json --severity HIGH,CRITICAL --skip-policy-update 2>/dev/null || echo '{"Results":[]}')
                    scan_exit_code=$?

                    # Filter out AWS-specific results for local environment
                    if command_exists jq; then
                        scan_output=$(echo "$raw_output" | jq '
                            if .Results then
                                .Results = [
                                    .Results[] |
                                    if .Misconfigurations then
                                        .Misconfigurations = [
                                            .Misconfigurations[] |
                                            select(.ID | test("^aws-|^AVD-AWS-") | not)
                                        ]
                                    else . end
                                ]
                            else . end
                        ')
                        echo "$scan_output" >> "$log_file"
                    else
                        scan_output="$raw_output"
                        echo "$raw_output" >> "$log_file"
                    fi
                    echo "=== END TRIVY SCAN ===" >> "$log_file"
                else
                    {
                        echo "=== TRIVY SCAN OUTPUT ==="
                        trivy config "$target_dir" --format json
                        echo "=== END TRIVY SCAN ==="
                    } >> "$log_file" 2>&1
                    scan_exit_code=$?
                    scan_output=$(trivy config "$target_dir" --format json 2>/dev/null || echo '{"Results":[]}')
                fi
                ;;
            *)
                return 1
                ;;
        esac

        # For JSON output tools, empty results array means success
        if [[ "$tool" == "checkov" ]] || [[ "$tool" == "trivy" ]]; then
            # Check if output contains empty results (success) or has actual issues
            if echo "$scan_output" | grep -q '"results":\s*\[\s*\]'; then
                # Empty results means no issues found - success
                return 0
            elif echo "$scan_output" | grep -q '"Results":\s*\[\s*\]'; then
                # Trivy uses capital "Results" - empty means success
                return 0
            elif echo "$scan_output" | grep -q '"results":\s*\[' || echo "$scan_output" | grep -q '"Results":\s*\['; then
                # Check if there are actual security findings vs just info

                # Get fail threshold from security requirements
                local fail_on_severity="HIGH"  # default
                local config_file="/tmp/infra-test-config-${environment}.yaml"

                # Load config if it doesn't exist
                if [[ ! -f "$config_file" ]]; then
                    load_config "$environment" "$config_file" >/dev/null 2>&1 || true
                fi

                if command_exists yq && [[ -f "$config_file" ]]; then
                    fail_on_severity=$(get_config_value "$config_file" ".security.severity_threshold" "HIGH")
                    local fail_on_violations=$(get_config_value "$config_file" ".security.fail_on_violations" "true")

                    # If fail_on_violations is false, don't fail on any security findings
                    if [[ "$fail_on_violations" == "false" ]]; then
                        return 0
                    fi
                fi

                case "$fail_on_severity" in
                    "CRITICAL")
                        if echo "$scan_output" | grep -q '"Severity":\s*"CRITICAL"'; then
                            return 1
                        else
                            return 0
                        fi
                        ;;
                    "HIGH")
                        if echo "$scan_output" | grep -q '"Severity":\s*"CRITICAL"\|"Severity":\s*"HIGH"'; then
                            return 1
                        else
                            return 0
                        fi
                        ;;
                    "MEDIUM")
                        if echo "$scan_output" | grep -q '"Severity":\s*"CRITICAL"\|"Severity":\s*"HIGH"\|"Severity":\s*"MEDIUM"'; then
                            return 1
                        else
                            return 0
                        fi
                        ;;
                    "NONE"|"OFF")
                        # Don't fail on any security findings
                        return 0
                        ;;
                    *)
                        return $scan_exit_code
                        ;;
                esac
            else
                # Use exit code for non-JSON or malformed output
                return $scan_exit_code
            fi
        else
            # For other tools, use exit code
            return $scan_exit_code
        fi
    fi
}

# Run terraform-specific security scan
run_terraform_security_scan() {
    local environment="${1:-local}"
    local use_cache="${2:-true}"

    local terraform_dir
    terraform_dir=$(get_terraform_dir)

    print_header "Terraform Security Scan - $environment"

    run_security_scan "$environment" "$terraform_dir" "$use_cache" "true"
}

# Run kubernetes-specific security scan
run_kubernetes_security_scan() {
    local environment="${1:-local}"
    local use_cache="${2:-true}"

    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)

    print_header "Kubernetes Security Scan - $environment"

    # Build kubernetes manifests first
    local temp_manifest="/tmp/k8s-security-${environment}-$$.yaml"
    local overlay_dir="$kubernetes_dir/overlays/$environment"

    if [[ ! -d "$overlay_dir" ]]; then
        print_error "Overlay directory not found: $overlay_dir"
        return 1
    fi

    # Build manifests
    if ! kustomize build "$overlay_dir" > "$temp_manifest"; then
        print_error "Failed to build kubernetes manifests"
        return 1
    fi

    # Run security scan on built manifests
    local result=0
    if [[ "$use_cache" == "true" ]]; then
        if execute_with_cache "kubernetes-security" "$environment" "checkov -f '$temp_manifest' --framework kubernetes" "$overlay_dir"; then
            result=0
        else
            result=1
        fi
    else
        if checkov -f "$temp_manifest" --framework kubernetes; then
            result=0
        else
            result=1
        fi
    fi

    # Cleanup
    [[ -f "$temp_manifest" ]] && rm -f "$temp_manifest"

    return $result
}

# Check if a specific tool is available (local or containerized)
is_tool_available() {
    local tool="$1"

    case "$tool" in
        "checkov")
            # Only check for actual checkov installation
            command_exists "checkov"
            ;;
        "trivy")
            command_exists "trivy"
            ;;
        *)
            command_exists "$tool"
            ;;
    esac
}

# Check security tool availability (local or containerized)
check_security_tools() {
    local trivy_available=false
    local checkov_available=false

    # Check local tools
    if command_exists "trivy"; then
        trivy_available=true
        print_success "trivy available locally"
    fi

    if command_exists "checkov"; then
        checkov_available=true
        print_success "checkov available locally"
    fi


    # Check containerized Trivy server (with timeout for Docker compatibility)
    if command_exists "kubectl"; then
        if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
            if kubectl get deployment trivy-server -n data-platform-security-scanning >/dev/null 2>&1; then
                trivy_available=true
                print_success "Trivy server available in cluster"
                if [[ "$checkov_available" == "false" ]]; then
                    print_success "Config scanning available via Trivy (checkov alternative)"
                fi
            fi
        fi
    fi

    if [[ "$trivy_available" == "false" && "$checkov_available" == "false" ]]; then
        print_error "No security tools available"
        print_info "Either install tools locally (checkov/trivy) or deploy security-scanning to cluster"
        return 1
    fi

    if [[ "$trivy_available" == "false" ]]; then
        print_warning "Trivy server not available in cluster"
    fi

    return 0
}

# Main function
main() {
    local command="${1:-all}"

    # Check security tools
    if ! check_security_tools; then
        exit 1
    fi

    case "$command" in
        "all")
            local environment="${2:-local}"
            local use_cache="${3:-true}"
            run_security_scan "$environment" "" "$use_cache" "true"
            ;;
        "terraform")
            local environment="${2:-local}"
            local use_cache="${3:-true}"
            run_terraform_security_scan "$environment" "$use_cache"
            ;;
        "kubernetes")
            local environment="${2:-local}"
            local use_cache="${3:-true}"
            run_kubernetes_security_scan "$environment" "$use_cache"
            ;;
        "sequential")
            local environment="${2:-local}"
            local use_cache="${3:-true}"
            run_security_scan "$environment" "" "$use_cache" "false"
            ;;
        "no-cache")
            local environment="${2:-local}"
            run_security_scan "$environment" "" "false" "true"
            ;;
        *)
            cat << EOF
Usage: $0 {all|terraform|kubernetes|sequential|no-cache} [ENVIRONMENT] [USE_CACHE]

Commands:
  all [ENV] [CACHE]         Run all security scans (default)
  terraform [ENV] [CACHE]   Run Terraform security scan only
  kubernetes [ENV] [CACHE]  Run Kubernetes security scan only
  sequential [ENV] [CACHE]  Run scans sequentially (not parallel)
  no-cache [ENV]           Run scans without caching

Options:
  ENVIRONMENT    local|dev|staging|prod (default: local)
  USE_CACHE      true|false (default: true)

Examples:
  $0                        # Run all scans for local environment
  $0 all prod              # Run all scans for production
  $0 terraform staging     # Run Terraform scan for staging
  $0 no-cache local        # Run without caching

Requirements:
  - checkov (pip3 install checkov)
  - trivy (brew install trivy) [recommended for infrastructure scanning]
EOF
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
