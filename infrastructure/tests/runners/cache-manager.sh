#!/bin/bash
# Cache management system for infrastructure testing
# Provides intelligent caching to skip expensive operations when inputs haven't changed

# Guard against multiple sourcing
if [[ -n "${_CACHE_MANAGER_SH_LOADED:-}" ]]; then
    return 0
fi
_CACHE_MANAGER_SH_LOADED=1

set -euo pipefail

# Source common utilities
CACHE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CACHE_SCRIPT_DIR/../lib/utils/common.sh"

# Cache configuration
CACHE_DIR="${CACHE_DIR:-$(get_tests_root)/.cache}"
CACHE_INDEX="$CACHE_DIR/index.json"
DEFAULT_MAX_AGE=60  # minutes

# Ensure cache directory exists
init_cache() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR"
        print_info "Cache directory created: $CACHE_DIR"
    fi
    
    if [[ ! -f "$CACHE_INDEX" ]]; then
        echo '{"version": "1.0", "entries": {}}' > "$CACHE_INDEX"
        print_info "Cache index initialized"
    fi
}

# Calculate content hash for files or directories
calculate_content_hash() {
    local path="$1"
    
    if [[ -f "$path" ]]; then
        get_file_hash "$path"
    elif [[ -d "$path" ]]; then
        get_directory_hash "$path"
    else
        echo "path_not_found"
    fi
}

# Create cache key from multiple inputs
create_cache_key() {
    local test_type="$1"
    local environment="$2"
    shift 2
    local input_paths=("$@")
    
    local key_components=("$test_type" "$environment")
    
    # Add content hashes of input paths
    for path in "${input_paths[@]}"; do
        local content_hash
        content_hash=$(calculate_content_hash "$path")
        key_components+=("$content_hash")
    done
    
    # Include tool versions in cache key
    local tool_versions=""
    if command_exists terraform; then
        tool_versions+="terraform:$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')"
    fi
    if command_exists checkov; then
        tool_versions+=":checkov:$(checkov --version 2>/dev/null | head -1 || echo 'unknown')"
    fi
    
    key_components+=("$tool_versions")
    
    create_cache_key "${key_components[@]}"
}

# Get cache entry metadata
get_cache_entry() {
    local cache_key="$1"
    
    if [[ ! -f "$CACHE_INDEX" ]]; then
        echo "null"
        return
    fi
    
    if command_exists jq; then
        jq -r ".entries[\"$cache_key\"] // null" "$CACHE_INDEX"
    else
        echo "null"
    fi
}

# Check if cache entry is valid
is_cache_entry_valid() {
    local cache_key="$1"
    local max_age_minutes="${2:-$DEFAULT_MAX_AGE}"
    
    local entry
    entry=$(get_cache_entry "$cache_key")
    
    if [[ "$entry" == "null" ]]; then
        return 1
    fi
    
    local cache_file result_file timestamp
    if command_exists jq; then
        cache_file=$(echo "$entry" | jq -r '.cache_file // empty')
        result_file=$(echo "$entry" | jq -r '.result_file // empty')
        timestamp=$(echo "$entry" | jq -r '.timestamp // 0')
    else
        return 1  # Fallback: no jq means no cache validation
    fi
    
    # Check if cache files exist
    if [[ ! -f "$cache_file" ]] || [[ ! -f "$result_file" ]]; then
        return 1
    fi
    
    # Check if cache entry is not too old
    local current_timestamp
    current_timestamp=$(date +%s)
    local age_minutes=$(( (current_timestamp - timestamp) / 60 ))
    
    [[ $age_minutes -lt $max_age_minutes ]]
}

# Store cache entry
store_cache_entry() {
    local cache_key="$1"
    local cache_file="$2"
    local result_file="$3"
    local exit_code="${4:-0}"
    local metadata="${5:-{}}"
    
    local timestamp
    timestamp=$(date +%s)
    
    local entry
    if command_exists jq; then
        entry=$(jq -n \
            --arg cache_file "$cache_file" \
            --arg result_file "$result_file" \
            --argjson timestamp "$timestamp" \
            --argjson exit_code "$exit_code" \
            --argjson metadata "$metadata" \
            '{
                cache_file: $cache_file,
                result_file: $result_file,
                timestamp: $timestamp,
                exit_code: $exit_code,
                metadata: $metadata
            }')
        
        # Update cache index
        local temp_index="/tmp/cache-index-$$.json"
        jq --arg key "$cache_key" --argjson entry "$entry" \
            '.entries[$key] = $entry' "$CACHE_INDEX" > "$temp_index"
        mv "$temp_index" "$CACHE_INDEX"
    fi
    
    print_success "Cache entry stored: $cache_key"
}

# Remove cache entry
remove_cache_entry() {
    local cache_key="$1"
    
    local entry
    entry=$(get_cache_entry "$cache_key")
    
    if [[ "$entry" != "null" ]] && command_exists jq; then
        local cache_file result_file
        cache_file=$(echo "$entry" | jq -r '.cache_file // empty')
        result_file=$(echo "$entry" | jq -r '.result_file // empty')
        
        # Remove cache files
        [[ -f "$cache_file" ]] && rm -f "$cache_file"
        [[ -f "$result_file" ]] && rm -f "$result_file"
        
        # Remove from index
        local temp_index="/tmp/cache-index-$$.json"
        jq --arg key "$cache_key" 'del(.entries[$key])' "$CACHE_INDEX" > "$temp_index"
        mv "$temp_index" "$CACHE_INDEX"
        
        print_info "Cache entry removed: $cache_key"
    fi
}

# Execute command with caching
execute_with_cache() {
    local test_type="$1"
    local environment="$2"
    local command="$3"
    shift 3
    local input_paths=("$@")
    
    init_cache
    
    # Create cache key
    local cache_key
    cache_key=$(create_cache_key "$test_type" "$environment" "${input_paths[@]}")
    
    local cache_file="$CACHE_DIR/${cache_key}.cache"
    local result_file="$CACHE_DIR/${cache_key}.result"
    
    # Check if cache is valid
    if is_cache_entry_valid "$cache_key"; then
        print_info "Cache hit for $test_type ($environment)"
        
        # Restore cached output
        if [[ -f "$result_file" ]]; then
            cat "$result_file"
        fi
        
        # Get cached exit code
        local cached_exit_code
        if command_exists jq; then
            cached_exit_code=$(get_cache_entry "$cache_key" | jq -r '.exit_code // 0')
        else
            cached_exit_code=0
        fi
        
        return "$cached_exit_code"
    fi
    
    print_info "Cache miss for $test_type ($environment) - executing command"
    
    # Execute command and capture output
    local exit_code=0
    if eval "$command" > "$result_file" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Store command and metadata in cache file
    cat > "$cache_file" << EOF
# Cached command execution for $test_type ($environment)
# Generated: $(date)
# Cache key: $cache_key
# Command: $command
# Input paths: ${input_paths[*]}
# Exit code: $exit_code

EOF
    
    # Store cache entry
    local metadata
    if command_exists jq; then
        metadata=$(jq -n \
            --arg command "$command" \
            --argjson input_paths "$(printf '%s\n' "${input_paths[@]}" | jq -R . | jq -s .)" \
            '{
                command: $command,
                input_paths: $input_paths
            }')
    else
        metadata="{}"
    fi
    
    store_cache_entry "$cache_key" "$cache_file" "$result_file" "$exit_code" "$metadata"
    
    # Output result
    cat "$result_file"
    
    return "$exit_code"
}

# Terraform plan caching
cache_terraform_plan() {
    local environment="$1"
    local terraform_dir="$2"
    
    local env_dir="$terraform_dir/environments/$environment"
    if [[ ! -d "$env_dir" ]]; then
        print_error "Environment directory not found: $env_dir"
        return 1
    fi
    
    local plan_command="cd '$env_dir' && terraform init -backend=false >/dev/null && terraform plan -out=tfplan"
    execute_with_cache "terraform-plan" "$environment" "$plan_command" "$env_dir"
}

# Security scan caching
cache_security_scan() {
    local tool="$1"
    local environment="$2"
    local target_dir="$3"
    local config_file="${4:-}"
    
    local scan_command
    case "$tool" in
        "checkov")
            if [[ -n "$config_file" ]]; then
                scan_command="checkov --config-file '$config_file' -d '$target_dir'"
            else
                scan_command="checkov -d '$target_dir'"
            fi
            ;;
        "trivy")
            scan_command="trivy config '$target_dir'"
            ;;
        *)
            print_error "Unknown security tool: $tool"
            return 1
            ;;
    esac
    
    execute_with_cache "security-$tool" "$environment" "$scan_command" "$target_dir" "${config_file:-}"
}

# Kubernetes manifest caching
cache_kubernetes_build() {
    local environment="$1"
    local overlay_dir="$2"
    
    if [[ ! -d "$overlay_dir" ]]; then
        print_error "Overlay directory not found: $overlay_dir"
        return 1
    fi
    
    local build_command="kustomize build '$overlay_dir'"
    execute_with_cache "kubernetes-build" "$environment" "$build_command" "$overlay_dir"
}

# OPA policy test caching
cache_opa_test() {
    local environment="$1"
    local policies_dir="$2"
    local manifest_file="$3"
    
    local test_command="opa eval -d '$policies_dir' -i '$manifest_file' 'data.kubernetes.security.deny[x]'"
    execute_with_cache "opa-policy" "$environment" "$test_command" "$policies_dir" "$manifest_file"
}

# Clean expired cache entries
clean_expired_cache() {
    local max_age_minutes="${1:-$DEFAULT_MAX_AGE}"
    
    print_header "Cleaning Expired Cache Entries"
    
    if [[ ! -f "$CACHE_INDEX" ]]; then
        print_info "No cache index found"
        return 0
    fi
    
    local expired_keys=()
    local current_timestamp
    current_timestamp=$(date +%s)
    
    if command_exists jq; then
        while IFS= read -r cache_key; do
            if [[ -n "$cache_key" ]]; then
                if ! is_cache_entry_valid "$cache_key" "$max_age_minutes"; then
                    expired_keys+=("$cache_key")
                fi
            fi
        done < <(jq -r '.entries | keys[]' "$CACHE_INDEX")
        
        # Remove expired entries
        for key in "${expired_keys[@]}"; do
            remove_cache_entry "$key"
        done
        
        print_info "Removed ${#expired_keys[@]} expired cache entries"
    fi
}

# Show cache statistics
show_cache_stats() {
    print_header "Cache Statistics"
    
    if [[ ! -f "$CACHE_INDEX" ]]; then
        print_info "No cache index found"
        return 0
    fi
    
    local total_entries=0
    local valid_entries=0
    local expired_entries=0
    local cache_size=0
    
    if command_exists jq; then
        total_entries=$(jq '.entries | length' "$CACHE_INDEX")
        
        while IFS= read -r cache_key; do
            if [[ -n "$cache_key" ]]; then
                if is_cache_entry_valid "$cache_key"; then
                    ((valid_entries++))
                else
                    ((expired_entries++))
                fi
            fi
        done < <(jq -r '.entries | keys[]' "$CACHE_INDEX")
        
        # Calculate cache directory size
        if [[ -d "$CACHE_DIR" ]]; then
            cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        fi
        
        echo "Cache directory: $CACHE_DIR"
        echo "Total entries: $total_entries"
        echo "Valid entries: $valid_entries"
        echo "Expired entries: $expired_entries"
        echo "Cache size: $cache_size"
    fi
}

# Clear all cache
clear_cache() {
    print_header "Clearing All Cache"
    
    if [[ -d "$CACHE_DIR" ]]; then
        rm -rf "$CACHE_DIR"
        print_success "Cache cleared"
    else
        print_info "Cache directory does not exist"
    fi
    
    init_cache
}

# Main function for CLI usage
main() {
    case "${1:-help}" in
        "init")
            init_cache
            ;;
        "stats")
            show_cache_stats
            ;;
        "clean")
            clean_expired_cache "${2:-$DEFAULT_MAX_AGE}"
            ;;
        "clear")
            clear_cache
            ;;
        "terraform-plan")
            cache_terraform_plan "${2}" "${3}"
            ;;
        "security-scan")
            cache_security_scan "${2}" "${3}" "${4}" "${5:-}"
            ;;
        "kubernetes-build")
            cache_kubernetes_build "${2}" "${3}"
            ;;
        "opa-test")
            cache_opa_test "${2}" "${3}" "${4}"
            ;;
        "execute")
            execute_with_cache "${2}" "${3}" "${4}" "${@:5}"
            ;;
        "help"|*)
            cat << EOF
Usage: $0 {init|stats|clean|clear|terraform-plan|security-scan|kubernetes-build|opa-test|execute} [OPTIONS]

Commands:
  init                          Initialize cache directory
  stats                         Show cache statistics
  clean [MAX_AGE]              Clean expired cache entries (default: $DEFAULT_MAX_AGE minutes)
  clear                        Clear all cache
  terraform-plan ENV DIR       Cache terraform plan for environment
  security-scan TOOL ENV DIR [CONFIG]  Cache security scan
  kubernetes-build ENV DIR    Cache kubernetes manifest build
  opa-test ENV POLICIES MANIFEST      Cache OPA policy test
  execute TYPE ENV CMD PATHS...       Execute command with caching

Examples:
  $0 init                                          # Initialize cache
  $0 stats                                         # Show cache statistics
  $0 clean 120                                     # Clean entries older than 2 hours
  $0 terraform-plan local ../terraform            # Cache terraform plan
  $0 security-scan checkov local ../terraform     # Cache security scan
  
Environment Variables:
  CACHE_DIR    Cache directory (default: .cache)
EOF
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi