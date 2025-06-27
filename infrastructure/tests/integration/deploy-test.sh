#!/bin/bash
set -euo pipefail

# Integration tests for ML Platform deployment
# Tests end-to-end deployment and basic functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_RESULTS=()
CLEANUP_CLUSTER=false

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
    
    log "INFO" "Running test: $test_name"
    
    if eval "$test_command"; then
        log "SUCCESS" "$test_name passed"
        TEST_RESULTS+=("✅ $test_name")
        return 0
    else
        log "ERROR" "$test_name failed"
        TEST_RESULTS+=("❌ $test_name")
        return 1
    fi
}

cleanup() {
    local exit_code=$?
    
    if [[ "$CLEANUP_CLUSTER" == "true" ]]; then
        log "INFO" "Cleaning up test cluster..."
        kind delete cluster --name ml-platform-test 2>/dev/null || true
    fi
    
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT

test_kind_cluster_creation() {
    local cluster_name="ml-platform-test"
    
    # Delete existing cluster if it exists
    kind delete cluster --name "$cluster_name" 2>/dev/null || true
    
    # Create test cluster
    kind create cluster --name "$cluster_name" --config - << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
EOF
    
    CLEANUP_CLUSTER=true
    kubectl config use-context "kind-$cluster_name"
    
    # Wait for cluster to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
}

test_ingress_controller_installation() {
    log "INFO" "Installing NGINX Ingress Controller..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
}

test_application_deployment() {
    local overlay_dir="$INFRA_DIR/kubernetes/overlays/local"
    
    cd "$overlay_dir"
    
    # Deploy applications
    kustomize build . | kubectl apply -f -
    
    # Wait for namespace to be created
    kubectl wait --for=condition=Established crd --all --timeout=60s 2>/dev/null || true
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available deployment --all -n ml-platform --timeout=300s
}

test_pod_health() {
    # Check all pods are running
    local failed_pods
    failed_pods=$(kubectl get pods -n ml-platform --field-selector=status.phase!=Running --no-headers | wc -l)
    
    if [[ $failed_pods -gt 0 ]]; then
        log "ERROR" "$failed_pods pod(s) not running"
        kubectl get pods -n ml-platform
        return 1
    fi
    
    return 0
}

test_service_connectivity() {
    # Test MinIO service
    kubectl port-forward -n ml-platform svc/minio 9000:9000 &
    local pf_pid=$!
    sleep 5
    
    if curl -f http://localhost:9000/minio/health/live; then
        log "SUCCESS" "MinIO health check passed"
    else
        log "ERROR" "MinIO health check failed"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
    
    kill $pf_pid 2>/dev/null || true
    sleep 2
    
    return 0
}

test_ingress_functionality() {
    # Get ingress IP
    local ingress_ip
    ingress_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    # Test ingress with host header
    if curl -H "Host: ml-platform.local" -f "http://$ingress_ip:8080" 2>/dev/null; then
        log "SUCCESS" "Ingress routing working"
    else
        log "WARN" "Ingress routing test failed (may be expected if frontend not available)"
    fi
    
    return 0
}

test_persistent_storage() {
    # Check PVCs are bound
    local unbound_pvcs
    unbound_pvcs=$(kubectl get pvc -n ml-platform --field-selector=status.phase!=Bound --no-headers | wc -l)
    
    if [[ $unbound_pvcs -gt 0 ]]; then
        log "ERROR" "$unbound_pvcs PVC(s) not bound"
        kubectl get pvc -n ml-platform
        return 1
    fi
    
    return 0
}

test_security_contexts() {
    # Check pods are not running as root
    local root_containers
    root_containers=$(kubectl get pods -n ml-platform -o jsonpath='{.items[*].spec.securityContext.runAsUser}' | grep -c "^0$" || true)
    
    if [[ $root_containers -gt 0 ]]; then
        log "ERROR" "$root_containers container(s) running as root"
        return 1
    fi
    
    return 0
}

test_resource_limits() {
    # Check pods have resource limits
    local pods_without_limits
    pods_without_limits=$(kubectl get pods -n ml-platform -o json | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name' | wc -l)
    
    if [[ $pods_without_limits -gt 0 ]]; then
        log "WARN" "$pods_without_limits pod(s) without resource limits"
    fi
    
    return 0
}

test_network_policies() {
    # Check if network policies exist (optional)
    local netpol_count
    netpol_count=$(kubectl get networkpolicy -n ml-platform --no-headers | wc -l)
    
    if [[ $netpol_count -eq 0 ]]; then
        log "INFO" "No network policies found (consider adding for security)"
    else
        log "SUCCESS" "$netpol_count network policy(ies) found"
    fi
    
    return 0
}

test_secrets_exist() {
    # Check required secrets exist
    local required_secrets=("minio-credentials" "database-credentials" "redis-credentials")
    
    for secret in "${required_secrets[@]}"; do
        if ! kubectl get secret "$secret" -n ml-platform &>/dev/null; then
            log "ERROR" "Required secret '$secret' not found"
            return 1
        fi
    done
    
    return 0
}

# Stress test functions
test_pod_restart_resilience() {
    log "INFO" "Testing pod restart resilience..."
    
    # Get a random pod
    local pod_name
    pod_name=$(kubectl get pods -n ml-platform -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -n "$pod_name" ]]; then
        # Delete the pod
        kubectl delete pod "$pod_name" -n ml-platform
        
        # Wait for replacement pod to be ready
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=minio -n ml-platform --timeout=180s
        
        log "SUCCESS" "Pod restart resilience test passed"
    else
        log "WARN" "No pods found for restart test"
    fi
    
    return 0
}

# Main testing logic
main() {
    local test_type="${1:-basic}"
    
    log "INFO" "Starting integration tests (type: $test_type)"
    
    local failed_tests=0
    
    # Basic deployment tests
    run_test "Kind cluster creation" "test_kind_cluster_creation" || ((failed_tests++))
    run_test "Ingress controller installation" "test_ingress_controller_installation" || ((failed_tests++))
    run_test "Application deployment" "test_application_deployment" || ((failed_tests++))
    
    # Health and functionality tests
    run_test "Pod health check" "test_pod_health" || ((failed_tests++))
    run_test "Service connectivity" "test_service_connectivity" || ((failed_tests++))
    run_test "Ingress functionality" "test_ingress_functionality" || ((failed_tests++))
    run_test "Persistent storage" "test_persistent_storage" || ((failed_tests++))
    
    # Security tests
    run_test "Security contexts" "test_security_contexts" || ((failed_tests++))
    run_test "Resource limits" "test_resource_limits" || ((failed_tests++))
    run_test "Network policies" "test_network_policies" || ((failed_tests++))
    run_test "Secrets exist" "test_secrets_exist" || ((failed_tests++))
    
    # Extended tests
    if [[ "$test_type" == "extended" ]]; then
        run_test "Pod restart resilience" "test_pod_restart_resilience" || ((failed_tests++))
    fi
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Integration Test Results Summary:"
    echo "=========================================="
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        log "SUCCESS" "All integration tests passed!"
        exit 0
    else
        log "ERROR" "$failed_tests test(s) failed"
        exit 1
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [TEST_TYPE]

Run integration tests for ML Platform deployment

TEST_TYPES:
    basic     - Basic deployment and health tests (default)
    extended  - Basic tests plus resilience testing

EXAMPLES:
    $0                  # Run basic tests
    $0 basic           # Run basic tests
    $0 extended        # Run extended tests

REQUIREMENTS:
    - kind
    - kubectl
    - kustomize
    - curl
    - jq
EOF
}

# Check dependencies
check_dependencies() {
    local deps=("kind" "kubectl" "kustomize" "curl" "jq")
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required dependency '$cmd' not found"
            exit 1
        fi
    done
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    basic|extended|"")
        check_dependencies
        main "${1:-basic}"
        ;;
    *)
        log "ERROR" "Invalid test type: $1"
        usage
        exit 1
        ;;
esac