#!/bin/bash
# Configuration loader for infrastructure testing
# Loads base configuration and applies environment-specific overrides

# Guard against multiple sourcing
if [[ -n "${_CONFIG_LOADER_SH_LOADED:-}" ]]; then
    return 0
fi
_CONFIG_LOADER_SH_LOADED=1

set -euo pipefail

# Source common utilities
CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CONFIG_SCRIPT_DIR/../utils/common.sh"

# Default environment
DEFAULT_ENVIRONMENT="local"

# Configuration paths
CONFIG_DIR="$CONFIG_SCRIPT_DIR"
BASE_CONFIG="$CONFIG_DIR/base.yaml"
ENVIRONMENTS_DIR="$CONFIG_DIR/environments"

# Load and merge configuration for specified environment
load_config() {
    local environment="${1:-$DEFAULT_ENVIRONMENT}"
    local output_file="${2:-/tmp/infra-test-config.yaml}"
    
    if [[ ! -f "$BASE_CONFIG" ]]; then
        print_error "Base configuration not found: $BASE_CONFIG"
        return 1
    fi
    
    local env_config="$ENVIRONMENTS_DIR/${environment}.yaml"
    if [[ ! -f "$env_config" ]]; then
        print_error "Environment configuration not found: $env_config"
        return 1
    fi
    
    print_info "Loading configuration for environment: $environment"
    
    # Use yq to merge configurations if available, otherwise use simple concatenation
    if command_exists yq; then
        # Merge base config with environment overrides using yq
        yq eval-all '. as $item ireduce ({}; . * $item)' "$BASE_CONFIG" "$env_config" > "$output_file"
    else
        # Fallback: simple concatenation with environment overrides taking precedence
        {
            echo "# Merged configuration for environment: $environment"
            echo "# Base configuration:"
            cat "$BASE_CONFIG"
            echo ""
            echo "# Environment overrides:"
            cat "$env_config"
        } > "$output_file"
    fi
    
    print_success "Configuration loaded: $output_file"
    return 0
}

# Get configuration value using yq or grep fallback
get_config_value() {
    local config_file="$1"
    local key_path="$2"
    local default_value="${3:-}"
    
    if [[ ! -f "$config_file" ]]; then
        echo "$default_value"
        return
    fi
    
    if command_exists yq; then
        # Use yq for precise YAML parsing
        local value
        value=$(yq eval "$key_path" "$config_file" 2>/dev/null || echo "null")
        if [[ "$value" == "null" || "$value" == "" ]]; then
            echo "$default_value"
        else
            echo "$value"
        fi
    else
        # Fallback: grep-based extraction (less precise but functional)
        local grep_pattern
        grep_pattern=$(echo "$key_path" | sed 's/\./\\\./g' | sed 's/\[/\\\[/g' | sed 's/\]/\\\]/g')
        
        local value
        value=$(grep -E "^\s*${grep_pattern#.}:" "$config_file" | head -1 | sed 's/.*://' | sed 's/^[ "]*//;s/[ "]*$//' || echo "")
        
        if [[ -z "$value" ]]; then
            echo "$default_value"
        else
            echo "$value"
        fi
    fi
}

# Get array values from configuration
get_config_array() {
    local config_file="$1"
    local key_path="$2"
    
    if [[ ! -f "$config_file" ]]; then
        return
    fi
    
    if command_exists yq; then
        yq eval "${key_path}[]" "$config_file" 2>/dev/null || true
    else
        # Fallback: extract array items with grep (basic implementation)
        local section_found=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*${key_path#.}:[[:space:]]*$ ]]; then
                section_found=true
                continue
            fi
            
            if [[ "$section_found" == "true" ]]; then
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*) ]]; then
                    echo "${BASH_REMATCH[1]}" | sed 's/^[ "]*//;s/[ "]*$//'
                elif [[ "$line" =~ ^[[:space:]]*[^[:space:]] ]]; then
                    # End of array section
                    break
                fi
            fi
        done < "$config_file"
    fi
}

# Generate tool-specific configuration files
generate_checkov_config() {
    local environment="$1"
    local config_file="${2:-/tmp/infra-test-config.yaml}"
    local output_file="${3:-/tmp/checkov-config.yaml}"
    
    local severity_threshold
    severity_threshold=$(get_config_value "$config_file" ".security.severity_threshold" "HIGH")
    
    local framework
    framework=$(get_config_value "$config_file" ".tools.checkov.framework" '["terraform", "kubernetes"]')
    
    local output_format
    output_format=$(get_config_value "$config_file" ".tools.checkov.output_format" "cli")
    
    local soft_fail
    soft_fail=$(get_config_value "$config_file" ".tools.checkov.soft_fail" "false")
    
    # Generate checkov configuration
    cat > "$output_file" << EOF
# Generated checkov configuration for $environment environment
check-severity: [$severity_threshold]
framework: $framework
output: $output_format
quiet: false
compact: true
soft-fail: $soft_fail

# Skip checks for $environment environment
skip-check:
EOF
    
    # Add skip checks
    get_config_array "$config_file" ".security.skip_checks.checkov" | while read -r check; do
        if [[ -n "$check" ]]; then
            echo "  - $check" >> "$output_file"
        fi
    done
    
    print_success "Generated checkov config: $output_file"
}


# Generate all tool configurations for an environment
generate_all_configs() {
    local environment="${1:-$DEFAULT_ENVIRONMENT}"
    local output_dir="${2:-/tmp}"
    
    local merged_config="$output_dir/infra-test-config-${environment}.yaml"
    
    # Load merged configuration
    if ! load_config "$environment" "$merged_config"; then
        return 1
    fi
    
    # Generate tool-specific configs
    generate_checkov_config "$environment" "$merged_config" "$output_dir/checkov-${environment}.yaml"
    # Note: tfsec has been replaced with trivy config scanning
    generate_security_tool_config "$environment" "trivy" "$output_dir/trivy-${environment}.yaml"
    
    print_success "All configurations generated for $environment environment"
}

# Validate configuration files
validate_config() {
    local environment="${1:-$DEFAULT_ENVIRONMENT}"
    
    print_info "Validating configuration for $environment"
    
    # Check if base config exists and is valid YAML
    if [[ ! -f "$BASE_CONFIG" ]]; then
        print_error "Base configuration not found"
        return 1
    fi
    
    if command_exists yq; then
        if ! yq eval . "$BASE_CONFIG" >/dev/null 2>&1; then
            print_error "Base configuration is not valid YAML"
            return 1
        fi
    fi
    
    # Check environment config
    local env_config="$ENVIRONMENTS_DIR/${environment}.yaml"
    if [[ ! -f "$env_config" ]]; then
        print_error "Environment configuration not found: $env_config"
        return 1
    fi
    
    if command_exists yq; then
        if ! yq eval . "$env_config" >/dev/null 2>&1; then
            print_error "Environment configuration is not valid YAML"
            return 1
        fi
    fi
    
    print_success "Configuration validation passed"
}

# List available environments
list_environments() {
    print_header "Available Environments"
    
    if [[ ! -d "$ENVIRONMENTS_DIR" ]]; then
        print_error "Environments directory not found: $ENVIRONMENTS_DIR"
        return 1
    fi
    
    for env_file in "$ENVIRONMENTS_DIR"/*.yaml; do
        if [[ -f "$env_file" ]]; then
            local env_name
            env_name=$(basename "$env_file" .yaml)
            print_info "$env_name"
        fi
    done
}

# Main function for CLI usage
main() {
    case "${1:-help}" in
        "load")
            load_config "${2:-$DEFAULT_ENVIRONMENT}" "${3:-/tmp/infra-test-config.yaml}"
            ;;
        "generate")
            generate_all_configs "${2:-$DEFAULT_ENVIRONMENT}" "${3:-/tmp}"
            ;;
        "validate")
            validate_config "${2:-$DEFAULT_ENVIRONMENT}"
            ;;
        "list")
            list_environments
            ;;
        "get")
            local config_file="${3:-/tmp/infra-test-config.yaml}"
            if [[ ! -f "$config_file" ]]; then
                load_config "${4:-$DEFAULT_ENVIRONMENT}" "$config_file"
            fi
            get_config_value "$config_file" "$2"
            ;;
        "help"|*)
            cat << EOF
Usage: $0 {load|generate|validate|list|get} [ENVIRONMENT] [OPTIONS]

Commands:
  load ENV [OUTPUT]     Load and merge configuration for environment
  generate ENV [DIR]    Generate all tool configs for environment
  validate ENV          Validate configuration for environment
  list                  List available environments
  get KEY [CONFIG]      Get configuration value by key path

Examples:
  $0 load local                                    # Load local config
  $0 generate production /tmp                      # Generate prod configs
  $0 validate staging                              # Validate staging config
  $0 get .security.severity_threshold config.yaml # Get config value

Available environments: local, development, staging, production
EOF
            ;;
    esac
}

# Load security requirements from YAML
load_security_requirements() {
    local environment="${1:-local}"
    local requirements_file="${2:-$CONFIG_DIR/../../config/security-requirements.yaml}"
    
    if [[ ! -f "$requirements_file" ]]; then
        print_error "Security requirements file not found: $requirements_file"
        return 1
    fi
    
    # Return the entire environment configuration
    yq eval ".environments.${environment}" "$requirements_file"
}

# Get specific security requirement value
get_security_requirement() {
    local environment="${1:-local}"
    local path="${2}"
    local default="${3:-}"
    local requirements_file="${4:-$CONFIG_DIR/../../config/security-requirements.yaml}"
    
    if [[ ! -f "$requirements_file" ]]; then
        echo "$default"
        return
    fi
    
    local value
    value=$(yq eval ".environments.${environment}.${path}" "$requirements_file" 2>/dev/null || echo "null")
    
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Check if should block on failure
should_block_on_failure() {
    local environment="${1:-local}"
    local block=$(get_security_requirement "$environment" "enforcement.block_on_failure" "false")
    [[ "$block" == "true" ]]
}

# Generate tool config from security requirements (YAML-based)
generate_security_tool_config() {
    local environment="${1:-local}"
    local tool="${2}"
    local output_file="${3}"
    local requirements_file="${4:-$CONFIG_DIR/../../config/security-requirements.yaml}"
    
    case "$tool" in
        "checkov")
            # Get settings from requirements
            local severity=$(get_security_requirement "$environment" "severity.minimum_severity" "HIGH")
            local soft_fail=$(get_security_requirement "$environment" "tools.checkov.soft_fail" "false")
            local compact=$(get_security_requirement "$environment" "tools.checkov.compact" "true")
            local frameworks=$(get_security_requirement "$environment" "tools.checkov.framework" '["terraform", "kubernetes"]')
            
            # Get exclusions for checkov (CKV_ checks)
            local exclusions
            if command_exists yq; then
                exclusions=$(yq eval ".environments.${environment}.exclusions[] | select(.id | test(\"^CKV_\")) | .id" "$requirements_file" 2>/dev/null | awk '{print "  - " $0}' || echo "")
            else
                exclusions=""
            fi
            
            cat > "$output_file" << EOF
# Generated checkov configuration for $environment environment
check-severity: [$severity]
framework: $frameworks
output: cli
quiet: false
compact: $compact
soft-fail: $soft_fail

# Skip checks for $environment environment
skip-check:
$exclusions
EOF
            ;;
            
        "tfsec")
            local severity=$(get_security_requirement "$environment" "tools.tfsec.minimum_severity" "HIGH")
            local soft_fail=$(get_security_requirement "$environment" "tools.tfsec.soft_fail" "false")
            
            # Get tfsec-specific exclusions
            local exclusions
            if command_exists yq; then
                exclusions=$(yq eval ".environments.${environment}.exclusions[] | select(.id | test(\"^(aws-|azure-|gcp-)\")) | .id" "$requirements_file" 2>/dev/null | awk '{print "  - " $0}' || echo "")
            else
                exclusions=""
            fi
            
            cat > "$output_file" << EOF
# Generated tfsec configuration for $environment environment
minimum_severity: $severity
soft_fail: $soft_fail
format: default

# Exclude checks for $environment environment
exclude:
$exclusions
EOF
            ;;
            
        "trivy")
            local severity=$(get_security_requirement "$environment" "tools.trivy.severity" '["CRITICAL", "HIGH"]')
            local timeout=$(get_security_requirement "$environment" "tools.trivy.timeout" "120")
            local skip_update=$(get_security_requirement "$environment" "tools.trivy.skip_update" "false")
            
            # Convert array to comma-separated string
            local severity_string
            if command_exists yq; then
                severity_string=$(echo "$severity" | yq eval '. | join(",")' - 2>/dev/null || echo "CRITICAL,HIGH")
            else
                severity_string="CRITICAL,HIGH"
            fi
            
            # Get trivy-specific exclusions (KSV* checks)
            local trivy_policy_file="/tmp/trivy-policy-${environment}.rego"
            local exclusions
            if command_exists yq; then
                exclusions=$(yq eval ".environments.${environment}.exclusions[] | select(.id | test(\"^KSV\")) | .id" "$requirements_file" 2>/dev/null || echo "")
            else
                exclusions=""
            fi
            
            # Generate policy file for trivy exclusions if needed
            if [[ -n "$exclusions" ]]; then
                cat > "$trivy_policy_file" << EOF
package trivy

import rego.v1

# Skip checks for $environment environment
skip contains check.id if {
    check := input
    check.id in [$(echo "$exclusions" | awk '{print "\"" $0 "\""}' | paste -sd, -)]
}
EOF
            fi
            
            cat > "$output_file" << EOF
# Generated Trivy configuration for $environment environment
severity: $severity_string
timeout: ${timeout}s
skip-update: $skip_update
format: json
quiet: false
$(if [[ -n "$exclusions" ]]; then echo "policy: $trivy_policy_file"; fi)
EOF
            ;;
    esac
    
    print_success "Generated $tool config for $environment: $output_file"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi