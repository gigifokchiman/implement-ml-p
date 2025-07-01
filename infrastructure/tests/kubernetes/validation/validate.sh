#!/bin/bash
set -euo pipefail

# Modern Kubernetes manifest validation using kubeconform
# Much faster and more reliable than kubectl validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBERNETES_DIR="$(cd "$SCRIPT_DIR/../../../kubernetes" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
}

# Check if kubeconform is installed
if ! command -v kubeconform &> /dev/null; then
    log "ERROR" "kubeconform not found. Install with: brew install kubeconform"
    exit 1
fi

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    log "ERROR" "kustomize not found. Install with: brew install kustomize"
    exit 1
fi

# Validate function
validate_overlay() {
    local overlay=$1
    local overlay_path="$KUBERNETES_DIR/overlays/$overlay"
    
    if [[ ! -d "$overlay_path" ]]; then
        log "WARN" "Overlay '$overlay' not found at $overlay_path"
        return 1
    fi
    
    log "INFO" "Validating $overlay overlay..."
    
    # Build manifests with kustomize
    local manifests
    if ! manifests=$(kustomize build "$overlay_path" 2>&1); then
        log "ERROR" "Failed to build $overlay with kustomize:"
        echo "$manifests"
        return 1
    fi
    
    # Validate with kubeconform
    local validation_output
    if validation_output=$(echo "$manifests" | kubeconform \
        -summary \
        -output json \
        -schema-location default \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
        - 2>&1); then
        
        # Parse results
        local valid=$(echo "$validation_output" | jq -r '.summary.valid // 0')
        local invalid=$(echo "$validation_output" | jq -r '.summary.invalid // 0')
        local errors=$(echo "$validation_output" | jq -r '.summary.errors // 0')
        local skipped=$(echo "$validation_output" | jq -r '.summary.skipped // 0')
        
        if [[ "$invalid" -gt 0 ]] || [[ "$errors" -gt 0 ]]; then
            log "ERROR" "Validation failed for $overlay:"
            echo "$validation_output" | jq -r '.resources[] | select(.status == "INVALID" or .status == "ERROR") | "\(.filename): \(.msg)"'
            return 1
        else
            log "SUCCESS" "$overlay validated successfully (Valid: $valid, Skipped: $skipped)"
        fi
    else
        log "ERROR" "kubeconform validation failed for $overlay:"
        echo "$validation_output"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    local environments=("local" "dev" "staging" "prod")
    local failed=0
    
    log "INFO" "Starting Kubernetes manifest validation"
    echo ""
    
    for env in "${environments[@]}"; do
        if ! validate_overlay "$env"; then
            ((failed++))
        fi
        echo ""
    done
    
    # Also validate base if it exists
    if [[ -d "$KUBERNETES_DIR/base" ]]; then
        log "INFO" "Validating base configuration..."
        if kustomize build "$KUBERNETES_DIR/base" | kubeconform -summary >/dev/null 2>&1; then
            log "SUCCESS" "Base configuration validated successfully"
        else
            log "ERROR" "Base configuration validation failed"
            ((failed++))
        fi
    fi
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        log "SUCCESS" "All Kubernetes manifests validated successfully!"
        exit 0
    else
        log "ERROR" "$failed environment(s) failed validation"
        exit 1
    fi
}

# Allow running specific overlay validation
if [[ $# -eq 1 ]]; then
    validate_overlay "$1"
else
    main
fi