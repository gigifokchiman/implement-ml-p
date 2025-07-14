#!/bin/bash
# OPA policy unit tests
# Execution time: < 2 minutes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/utils/common.sh"
source "$SCRIPT_DIR/../../runners/cache-manager.sh"

# Run OPA policy unit tests
run_opa_policy_tests() {
    local policies_dir="${1:-}"
    local use_cache="${2:-true}"
    
    if [[ -z "$policies_dir" ]]; then
        local kubernetes_dir
        kubernetes_dir=$(get_kubernetes_dir)
        policies_dir="$kubernetes_dir/policies"
    fi
    
    print_header "OPA Policy Unit Tests"
    
    if [[ ! -d "$policies_dir" ]]; then
        print_warning "Policies directory not found: $policies_dir"
        print_info "No OPA policies to test"
        return 0
    fi
    
    # Check if there are any policy files
    local policy_files
    policy_files=$(find "$policies_dir" -name "*.rego" 2>/dev/null || true)
    
    if [[ -z "$policy_files" ]]; then
        print_warning "No OPA policy files found in: $policies_dir"
        return 0
    fi
    
    # Check if there are any test files
    local test_files
    test_files=$(find "$policies_dir" -name "*_test.rego" 2>/dev/null || true)
    
    if [[ -z "$test_files" ]]; then
        print_warning "No OPA test files found in: $policies_dir"
        print_info "Create *_test.rego files to enable policy testing"
        return 0
    fi
    
    print_info "Found policy files:"
    echo "$policy_files" | while read -r file; do
        if [[ ! "$file" =~ _test\.rego$ ]]; then
            print_info "  $(basename "$file")"
        fi
    done
    
    print_info "Found test files:"
    echo "$test_files" | while read -r file; do
        print_info "  $(basename "$file")"
    done
    
    # Run the tests
    print_info "Running OPA policy tests..."
    local test_cmd="opa test '$policies_dir' -v"
    
    if eval "$test_cmd"; then
        print_success "OPA policy tests passed"
        return 0
    else
        print_error "OPA policy tests failed"
        return 1
    fi
}

# Run policy tests against specific manifests
run_policy_validation() {
    local environment="${1:-local}"
    local policies_dir="${2:-}"
    local use_cache="${3:-true}"
    
    if [[ -z "$policies_dir" ]]; then
        local kubernetes_dir
        kubernetes_dir=$(get_kubernetes_dir)
        policies_dir="$kubernetes_dir/policies"
    fi
    
    print_header "OPA Policy Validation - $environment"
    
    if [[ ! -d "$policies_dir" ]]; then
        print_error "Policies directory not found: $policies_dir"
        return 1
    fi
    
    # Build kubernetes manifests for the environment
    local kubernetes_dir
    kubernetes_dir=$(get_kubernetes_dir)
    local overlay_dir="$kubernetes_dir/overlays/$environment"
    
    if [[ ! -d "$overlay_dir" ]]; then
        print_error "Overlay directory not found: $overlay_dir"
        return 1
    fi
    
    local temp_manifest="/tmp/k8s-opa-${environment}-$$.yaml"
    
    # Build manifests
    if ! kustomize build "$overlay_dir" > "$temp_manifest"; then
        print_error "Failed to build kubernetes manifests for $environment"
        return 1
    fi
    
    print_info "Validating $environment manifests against policies..."
    
    # Run policy evaluation
    local eval_cmd="opa eval -d '$policies_dir' -i '$temp_manifest' 'data.kubernetes.security.deny[x]'"
    local violations_cmd="$eval_cmd | jq -e '.result[0].expressions[0].value | length == 0'"
    
    local result=0
    if [[ "$use_cache" == "true" ]]; then
        if cache_opa_test "$environment" "$policies_dir" "$temp_manifest"; then
            result=0
        else
            result=1
        fi
    else
        # Check for violations
        if eval "$violations_cmd" >/dev/null 2>&1; then
            print_success "No policy violations found for $environment"
            result=0
        else
            print_error "Policy violations found for $environment"
            print_info "Violations:"
            eval "$eval_cmd" | jq '.result[0].expressions[0].value[]' 2>/dev/null || true
            result=1
        fi
    fi
    
    # Cleanup
    [[ -f "$temp_manifest" ]] && rm -f "$temp_manifest"
    
    return $result
}

# List available policies
list_policies() {
    local policies_dir="${1:-}"
    
    if [[ -z "$policies_dir" ]]; then
        local kubernetes_dir
        kubernetes_dir=$(get_kubernetes_dir)
        policies_dir="$kubernetes_dir/policies"
    fi
    
    print_header "Available OPA Policies"
    
    if [[ ! -d "$policies_dir" ]]; then
        print_info "Policies directory not found: $policies_dir"
        return 0
    fi
    
    local policy_files
    policy_files=$(find "$policies_dir" -name "*.rego" 2>/dev/null || true)
    
    if [[ -z "$policy_files" ]]; then
        print_info "No policy files found in: $policies_dir"
    else
        echo "$policy_files" | while read -r file; do
            local file_type="policy"
            if [[ "$file" =~ _test\.rego$ ]]; then
                file_type="test"
            fi
            
            local relative_path
            relative_path=$(realpath --relative-to="$policies_dir" "$file" 2>/dev/null || basename "$file")
            print_info "  $relative_path ($file_type)"
        done
    fi
}

# Create example policy and test files
create_example_policy() {
    local policies_dir="${1:-}"
    local policy_name="${2:-example}"
    
    if [[ -z "$policies_dir" ]]; then
        local kubernetes_dir
        kubernetes_dir=$(get_kubernetes_dir)
        policies_dir="$kubernetes_dir/policies"
    fi
    
    print_header "Creating Example Policy Files"
    
    if [[ ! -d "$policies_dir" ]]; then
        mkdir -p "$policies_dir"
        print_info "Created policies directory: $policies_dir"
    fi
    
    local policy_file="$policies_dir/${policy_name}.rego"
    local test_file="$policies_dir/${policy_name}_test.rego"
    
    # Create policy file
    if [[ ! -f "$policy_file" ]]; then
        cat > "$policy_file" << 'EOF'
package kubernetes.security

# Deny containers that run as root user
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.containers[_].securityContext.runAsUser == 0
    msg := "Container should not run as root user"
}

# Deny containers without resource limits
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container '%s' should have resource limits", [container.name])
}

# Deny containers using latest tag
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%s' should not use 'latest' tag", [container.name])
}
EOF
        print_success "Created policy file: $policy_file"
    else
        print_warning "Policy file already exists: $policy_file"
    fi
    
    # Create test file
    if [[ ! -f "$test_file" ]]; then
        cat > "$test_file" << 'EOF'
package kubernetes.security

# Test: should deny root user
test_deny_root_user {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "securityContext": {
                            "runAsUser": 0
                        }
                    }]
                }
            }
        }
    }
}

# Test: should allow non-root user
test_allow_non_root_user {
    count(deny) == 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "nginx:1.20",
                        "securityContext": {
                            "runAsUser": 1000
                        },
                        "resources": {
                            "limits": {
                                "memory": "128Mi",
                                "cpu": "100m"
                            }
                        }
                    }]
                }
            }
        }
    }
}

# Test: should deny missing resource limits
test_deny_missing_limits {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "nginx:1.20"
                    }]
                }
            }
        }
    }
}

# Test: should deny latest tag
test_deny_latest_tag {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "nginx:latest",
                        "resources": {
                            "limits": {
                                "memory": "128Mi",
                                "cpu": "100m"
                            }
                        }
                    }]
                }
            }
        }
    }
}
EOF
        print_success "Created test file: $test_file"
    else
        print_warning "Test file already exists: $test_file"
    fi
}

# Check OPA tool availability
check_opa_tool() {
    if ! command_exists opa; then
        print_error "OPA is not installed"
        print_info "Install with: brew install opa"
        return 1
    fi
    
    print_info "OPA version: $(opa version)"
    return 0
}

# Main function
main() {
    local command="${1:-test}"
    
    # Check OPA tool
    if ! check_opa_tool; then
        exit 1
    fi
    
    case "$command" in
        "test")
            local policies_dir="${2:-}"
            local use_cache="${3:-true}"
            run_opa_policy_tests "$policies_dir" "$use_cache"
            ;;
        "validate")
            local environment="${2:-local}"
            local policies_dir="${3:-}"
            local use_cache="${4:-true}"
            run_policy_validation "$environment" "$policies_dir" "$use_cache"
            ;;
        "list")
            local policies_dir="${2:-}"
            list_policies "$policies_dir"
            ;;
        "create")
            local policies_dir="${2:-}"
            local policy_name="${3:-example}"
            create_example_policy "$policies_dir" "$policy_name"
            ;;
        "no-cache")
            local policies_dir="${2:-}"
            run_opa_policy_tests "$policies_dir" "false"
            ;;
        *)
            cat << EOF
Usage: $0 {test|validate|list|create|no-cache} [OPTIONS]

Commands:
  test [POLICIES_DIR] [CACHE]        Run policy unit tests (default)
  validate ENV [POLICIES_DIR] [CACHE] Validate environment against policies
  list [POLICIES_DIR]                List available policies
  create [POLICIES_DIR] [NAME]       Create example policy files
  no-cache [POLICIES_DIR]           Run tests without caching

Options:
  POLICIES_DIR  Directory containing .rego files (default: kubernetes/policies)
  ENV          Environment to validate (local|dev|staging|prod)
  NAME         Name for new policy (default: example)
  CACHE        Use caching true|false (default: true)

Examples:
  $0                                # Run all policy unit tests
  $0 validate staging              # Validate staging against policies
  $0 list                         # List available policies
  $0 create . security_rules      # Create example policy files
  $0 no-cache                     # Run tests without cache

Requirements:
  - opa (brew install opa)
  - kustomize (for validation command)
  - jq (for parsing results)

Policy File Format:
  Create .rego files with deny rules and *_test.rego files with test cases.
EOF
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi