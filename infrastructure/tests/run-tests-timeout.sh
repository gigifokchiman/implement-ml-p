#!/bin/bash
# Timeout wrapper for run-tests.sh to prevent hanging
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT=${TIMEOUT:-180}  # 3 minutes default

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to run command with timeout
run_with_timeout() {
    local timeout_duration=$1
    shift
    local cmd="$*"
    
    echo "Running: $cmd (timeout: ${timeout_duration}s)"
    
    # Start the command in background
    $cmd &
    local cmd_pid=$!
    
    # Start timeout in background
    (
        sleep $timeout_duration
        if kill -0 $cmd_pid 2>/dev/null; then
            echo "Command timed out after ${timeout_duration}s, killing process..."
            kill -TERM $cmd_pid 2>/dev/null || true
            sleep 2
            kill -KILL $cmd_pid 2>/dev/null || true
        fi
    ) &
    local timeout_pid=$!
    
    # Wait for command to complete
    if wait $cmd_pid; then
        # Command completed successfully, kill timeout
        kill $timeout_pid 2>/dev/null || true
        return 0
    else
        local exit_code=$?
        # Command failed, kill timeout
        kill $timeout_pid 2>/dev/null || true
        return $exit_code
    fi
}

echo "========================================"
echo "Infrastructure Tests with Timeout Protection"
echo "========================================"
echo "Timeout: ${TIMEOUT} seconds"
echo ""

# Try to run tests with timeout protection
if run_with_timeout $TIMEOUT ./run-tests.sh "$@"; then
    print_success "All tests completed successfully!"
    exit 0
else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        print_error "Tests timed out after ${TIMEOUT} seconds"
        print_warning "Some tests may be hanging due to network issues"
        echo ""
        echo "Try these alternatives:"
        echo "  ./run-tests-simple.sh        # Quick basic tests"
        echo "  ./test-checkov.sh            # Test security scanning only"
        echo "  USE_PARALLEL=false ./run-tests.sh  # Disable parallel execution"
    else
        print_error "Tests failed with exit code: $exit_code"
    fi
    exit $exit_code
fi