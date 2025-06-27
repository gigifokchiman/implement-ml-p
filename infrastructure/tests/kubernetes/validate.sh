#!/bin/bash
set -euo pipefail

# Kubernetes manifest validation and testing script
# Tests all overlays for syntax, security, and best practices

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_RESULTS=()

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
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $timestamp - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $timestamp - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message" ;;
    esac
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local environment="$3"
    
    log "INFO" "Running test: $test_name ($environment)"
    
    if eval "$test_command"; then
        log "SUCCESS" "$test_name passed ($environment)"
        TEST_RESULTS+=("✅ $test_name ($environment)")
        return 0
    else
        log "ERROR" "$test_name failed ($environment)"
        TEST_RESULTS+=("❌ $test_name ($environment)")
        return 1
    fi
}

test_kustomize_build() {
    local overlay_dir="$1"
    cd "$overlay_dir"
    kustomize build . > /dev/null
}

test_kubectl_validate() {
    local overlay_dir="$1"
    cd "$overlay_dir"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log "INFO" "kubectl not available - skipping cluster validation"
        log "INFO" "To enable kubectl validation: install kubectl and connect to a cluster"
        return 0
    fi
    
    # Check if cluster is available
    if kubectl cluster-info &> /dev/null; then
        log "INFO" "Cluster available - running server-side validation"
        kustomize build . | kubectl apply --dry-run=server -f - > /dev/null 2>&1
    else
        log "INFO" "No cluster running - skipping kubectl validation"
        log "INFO" "To enable kubectl validation: start a cluster first"
        log "INFO" "  Local: make dev-kind-up"
        log "INFO" "  Cloud: make dev-aws-up"
        return 0
    fi
}

test_security_policies() {
    local overlay_dir="$1"
    local environment="$2"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Check for security contexts
    if ! echo "$manifests" | grep -q "securityContext:"; then
        log "ERROR" "No security contexts found in manifests"
        return 1
    fi
    
    # Check for non-root containers
    if echo "$manifests" | grep -q "runAsUser: 0"; then
        log "ERROR" "Found containers running as root (runAsUser: 0)"
        return 1
    fi
    
    # Check for privileged containers
    if echo "$manifests" | grep -q "privileged: true"; then
        log "ERROR" "Found privileged containers"
        return 1
    fi
    
    # Check for resource limits
    if ! echo "$manifests" | grep -q "limits:"; then
        log "WARN" "No resource limits found in manifests"
        if [[ "$environment" == "prod" ]]; then
            return 1
        fi
    fi
    
    return 0
}

test_namespace_consistency() {
    local overlay_dir="$1"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Get all namespaces from manifests
    local namespaces
    namespaces=$(echo "$manifests" | grep -E "^\s*namespace:" | awk '{print $2}' | sort -u)
    
    # Check if all resources use the same namespace
    local namespace_count
    namespace_count=$(echo "$namespaces" | wc -l)
    
    if [[ $namespace_count -gt 1 ]]; then
        log "ERROR" "Multiple namespaces found: $(echo "$namespaces" | tr '\n' ' ')"
        return 1
    fi
    
    return 0
}

test_image_tags() {
    local overlay_dir="$1"
    local environment="$2"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Check for :latest tags in production
    if [[ "$environment" == "prod" ]]; then
        if echo "$manifests" | grep -q "image:.*:latest"; then
            log "ERROR" "Found :latest image tags in production environment"
            return 1
        fi
    fi
    
    # Check for missing image tags
    if echo "$manifests" | grep -E "image:.*[^:]$"; then
        log "WARN" "Found images without explicit tags"
    fi
    
    return 0
}

test_secret_management() {
    local overlay_dir="$1"
    local environment="$2"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Check for hardcoded secrets (basic check)
    if echo "$manifests" | grep -iE "(password|secret|key).*:\s*[\"'][^\"']{8,}[\"']"; then
        log "ERROR" "Potential hardcoded secrets found in manifests"
        return 1
    fi
    
    # Check that secrets exist
    if ! echo "$manifests" | grep -q "kind: Secret"; then
        log "WARN" "No Secret resources found - ensure external secret management is configured"
    fi
    
    return 0
}

test_ingress_configuration() {
    local overlay_dir="$1"
    local environment="$2"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Check for ingress resources
    if echo "$manifests" | grep -q "kind: Ingress"; then
        # Check for TLS configuration in production
        if [[ "$environment" == "prod" ]]; then
            if ! echo "$manifests" | grep -q "tls:"; then
                log "ERROR" "Production ingress should have TLS configuration"
                return 1
            fi
        fi
        
        # Check for ingress class
        if ! echo "$manifests" | grep -q "ingressClassName:"; then
            log "WARN" "Ingress resources should specify ingressClassName"
        fi
    fi
    
    return 0
}

test_storage_configuration() {
    local overlay_dir="$1"
    local environment="$2"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Check for PVC resources
    if echo "$manifests" | grep -q "kind: PersistentVolumeClaim"; then
        # Check storage class is specified
        if ! echo "$manifests" | grep -q "storageClassName:"; then
            log "ERROR" "PVC should specify storage class"
            return 1
        fi
        
        # Check storage size for production
        if [[ "$environment" == "prod" ]]; then
            if echo "$manifests" | grep -E "storage.*[0-9]+Gi" | grep -E "[0-9]Gi"; then
                log "WARN" "Production PVC might have small storage size"
            fi
        fi
    fi
    
    return 0
}

test_health_checks() {
    local overlay_dir="$1"
    cd "$overlay_dir"
    
    local manifests
    manifests=$(kustomize build .)
    
    # Check for liveness and readiness probes
    if echo "$manifests" | grep -q "kind: Deployment"; then
        if ! echo "$manifests" | grep -q "livenessProbe:"; then
            log "WARN" "Deployments should have liveness probes"
        fi
        
        if ! echo "$manifests" | grep -q "readinessProbe:"; then
            log "WARN" "Deployments should have readiness probes"
        fi
    fi
    
    return 0
}

test_kustomize_lint() {
    local overlay_dir="$1"
    
    # Install kustomize-lint if available
    if command -v kustomize-lint &> /dev/null; then
        cd "$overlay_dir"
        kustomize-lint .
    else
        log "INFO" "kustomize-lint not available, skipping lint check"
        return 0
    fi
}

# Main testing logic
main() {
    log "INFO" "Starting Kubernetes manifest tests"
    
    local environments=("local" "dev" "staging" "prod")
    local failed_tests=0
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ ! -d "$overlay_dir" ]]; then
            log "WARN" "Overlay directory not found: $overlay_dir"
            continue
        fi
        
        log "INFO" "Testing environment: $env"
        
        # Basic Kubernetes tests
        run_test "kustomize build" "test_kustomize_build '$overlay_dir'" "$env" || ((failed_tests++))
        run_test "kubectl validate" "test_kubectl_validate '$overlay_dir'" "$env" || ((failed_tests++))
        
        # Security and compliance tests
        run_test "security policies" "test_security_policies '$overlay_dir' '$env'" "$env" || ((failed_tests++))
        run_test "namespace consistency" "test_namespace_consistency '$overlay_dir'" "$env" || ((failed_tests++))
        run_test "image tags" "test_image_tags '$overlay_dir' '$env'" "$env" || ((failed_tests++))
        run_test "secret management" "test_secret_management '$overlay_dir' '$env'" "$env" || ((failed_tests++))
        run_test "ingress configuration" "test_ingress_configuration '$overlay_dir' '$env'" "$env" || ((failed_tests++))
        run_test "storage configuration" "test_storage_configuration '$overlay_dir' '$env'" "$env" || ((failed_tests++))
        run_test "health checks" "test_health_checks '$overlay_dir'" "$env" || ((failed_tests++))
        run_test "kustomize lint" "test_kustomize_lint '$overlay_dir'" "$env" || ((failed_tests++))
        
        echo ""
    done
    
    # Test base configuration
    local base_dir="$INFRA_DIR/kubernetes/base"
    if [[ -d "$base_dir" ]]; then
        log "INFO" "Testing base configuration"
        run_test "base kustomize build" "test_kustomize_build '$base_dir'" "base" || ((failed_tests++))
        echo ""
    fi
    
    # Summary
    echo "=========================================="
    echo "Test Results Summary:"
    echo "=========================================="
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        log "SUCCESS" "All Kubernetes tests passed!"
        exit 0
    else
        log "ERROR" "$failed_tests test(s) failed"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("kubectl" "kustomize")
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required dependency '$cmd' not found"
            exit 1
        fi
    done
}

check_dependencies
main "$@"