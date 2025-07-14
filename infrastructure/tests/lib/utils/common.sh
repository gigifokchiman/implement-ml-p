#!/bin/bash
# Common utilities for infrastructure testing
# Provides shared functions for path resolution, error handling, and output formatting

# Guard against multiple sourcing
if [[ -n "${_COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
_COMMON_SH_LOADED=1

set -euo pipefail

# Colors for output (only set if not already defined)
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
fi

# Get the root directory of the tests
get_tests_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

# Get the infrastructure root directory
get_infra_root() {
    echo "$(cd "$(get_tests_root)/.." && pwd)"
}

# Get terraform directory
get_terraform_dir() {
    echo "$(get_infra_root)/terraform"
}

# Get kubernetes directory
get_kubernetes_dir() {
    echo "$(get_infra_root)/kubernetes"
}

# Print formatted header
print_header() {
    local message="$1"
    echo ""
    echo "======================================"
    echo "$message"
    echo "======================================"
    echo ""
}

# Print success message
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Progress spinner
show_spinner() {
    local pid=$1
    local message="$2"
    local spinner='|/-\'
    local i=0
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spinner:$i:1}"
        sleep 0.1
        i=$(( (i+1) % 4 ))
    done
    printf "\b✓\n"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local width=30
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r$message ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $((width - filled)) | tr ' ' '-'
    printf "] %d%%" $percentage
    
    if [[ $current -eq $total ]]; then
        echo " ✓"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if tool is installed and install if missing
ensure_tool() {
    local tool="$1"
    local install_cmd="${2:-}"
    
    if command_exists "$tool"; then
        print_info "$tool is already installed"
        return 0
    fi
    
    if [[ -n "$install_cmd" ]]; then
        print_info "Installing $tool..."
        eval "$install_cmd"
    else
        print_error "$tool is not installed. Please install it manually."
        return 1
    fi
}

# Run command with proper error handling and logging
run_command() {
    local description="$1"
    shift
    local cmd=("$@")
    
    print_info "Running: $description"
    
    if "${cmd[@]}"; then
        print_success "$description completed"
        return 0
    else
        print_error "$description failed"
        return 1
    fi
}

# Run command with timeout
run_command_with_timeout() {
    local timeout_seconds="$1"
    local description="$2"
    shift 2
    local cmd=("$@")
    
    print_info "Running: $description (timeout: ${timeout_seconds}s)"
    
    # Run command in background
    "${cmd[@]}" &
    local cmd_pid=$!
    
    # Start timeout counter
    local elapsed=0
    while kill -0 $cmd_pid 2>/dev/null; do
        if [[ $elapsed -ge $timeout_seconds ]]; then
            kill $cmd_pid 2>/dev/null
            print_error "$description timed out after ${timeout_seconds}s"
            return 124  # Standard timeout exit code
        fi
        sleep 1
        ((elapsed++))
        
        # Show progress dots
        if [[ $((elapsed % 5)) -eq 0 ]]; then
            echo -n "."
        fi
    done
    
    # Get the exit status
    wait $cmd_pid
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "$description completed"
        return 0
    else
        print_error "$description failed with exit code $exit_code"
        return $exit_code
    fi
}

# Get file hash for caching
get_file_hash() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        shasum -a 256 "$file_path" | cut -d' ' -f1
    else
        echo "file_not_found"
    fi
}

# Get directory hash for caching (recursive)
get_directory_hash() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        find "$dir_path" -type f -exec shasum -a 256 {} \; | sort | shasum -a 256 | cut -d' ' -f1
    else
        echo "dir_not_found"
    fi
}

# Create cache key from multiple inputs
create_cache_key() {
    local key_parts=("$@")
    printf '%s\n' "${key_parts[@]}" | shasum -a 256 | cut -d' ' -f1
}

# Check if cache entry is valid
is_cache_valid() {
    local cache_file="$1"
    local max_age_minutes="${2:-60}"  # Default 1 hour
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local file_age_minutes
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        file_age_minutes=$(( ($(date +%s) - $(stat -f %m "$cache_file")) / 60 ))
    else
        # Linux
        file_age_minutes=$(( ($(date +%s) - $(stat -c %Y "$cache_file")) / 60 ))
    fi
    
    [[ $file_age_minutes -lt $max_age_minutes ]]
}

# Parse JSON output for errors
parse_json_errors() {
    local json_file="$1"
    local severity_filter="${2:-CRITICAL}"
    
    if [[ -f "$json_file" ]] && command_exists jq; then
        jq -r ".results[]? | select(.severity == \"$severity_filter\") | .description" "$json_file" 2>/dev/null || true
    fi
}

# Track test results (global variables without -g for compatibility)
PASSED_TESTS=${PASSED_TESTS:-0}
FAILED_TESTS=${FAILED_TESTS:-0}

# Record test result
record_test_result() {
    local test_name="$1"
    local exit_code="$2"
    local allow_failure="${3:-false}"
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "$test_name passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        if [[ "$allow_failure" == "true" ]]; then
            print_warning "$test_name failed (non-blocking)"
            PASSED_TESTS=$((PASSED_TESTS + 1))  # Count as passed for non-blocking failures
        else
            print_error "$test_name failed"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

# Print test summary
print_test_summary() {
    local total=$((PASSED_TESTS + FAILED_TESTS))
    
    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Total:  $total"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "$FAILED_TESTS test(s) failed"
        return 1
    fi
}

# Cleanup function for temporary files
cleanup_temp_files() {
    local pattern="${1:-/tmp/infra-test-*}"
    rm -f $pattern 2>/dev/null || true
}

# Set up trap for cleanup
setup_cleanup_trap() {
    trap 'cleanup_temp_files' EXIT
}