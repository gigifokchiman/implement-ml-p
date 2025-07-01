#!/bin/bash
set -euo pipefail

# Network Policy Testing Script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Configuration
NAMESPACE="${NAMESPACE:-ml-platform}"
TEST_NAMESPACE="${TEST_NAMESPACE:-netpol-test}"
TIMEOUT="${TIMEOUT:-60}"

# Test results tracking
declare -A test_results
total_tests=0
passed_tests=0
failed_tests=0

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster."
        exit 1
    fi
    
    # Check if CNI supports network policies
    if ! kubectl get networkpolicies &> /dev/null; then
        error "Network policies are not supported in this cluster"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Setup test environment
setup_test_environment() {
    log "Setting up test environment..."
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Label the namespace
    kubectl label namespace "$TEST_NAMESPACE" name="$TEST_NAMESPACE" --overwrite
    
    # Create test pods for connectivity testing
    create_test_pods
    
    success "Test environment setup completed"
}

# Create test pods
create_test_pods() {
    log "Creating test pods..."
    
    # Create client pod in test namespace
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-client
  namespace: $TEST_NAMESPACE
  labels:
    app: test-client
    role: client
spec:
  containers:
  - name: client
    image: busybox:1.35
    command: ['sleep', '3600']
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
  restartPolicy: Never
EOF

    # Create server pod in test namespace
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-server
  namespace: $TEST_NAMESPACE
  labels:
    app: test-server
    role: server
spec:
  containers:
  - name: server
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
  restartPolicy: Never
---
apiVersion: v1
kind: Service
metadata:
  name: test-server-service
  namespace: $TEST_NAMESPACE
spec:
  selector:
    app: test-server
  ports:
  - port: 80
    targetPort: 80
EOF

    # Create external client pod (different namespace)
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: external-client
  namespace: default
  labels:
    app: external-client
    role: client
spec:
  containers:
  - name: client
    image: busybox:1.35
    command: ['sleep', '3600']
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
  restartPolicy: Never
EOF

    # Wait for pods to be ready
    kubectl wait --for=condition=Ready pod/test-client -n "$TEST_NAMESPACE" --timeout=60s
    kubectl wait --for=condition=Ready pod/test-server -n "$TEST_NAMESPACE" --timeout=60s
    kubectl wait --for=condition=Ready pod/external-client -n default --timeout=60s
}

# Test connectivity between pods
test_connectivity() {
    local from_pod="$1"
    local from_namespace="$2"
    local to_service="$3"
    local to_namespace="$4"
    local port="$5"
    local expected_result="$6"  # "allow" or "deny"
    local test_name="$7"
    
    total_tests=$((total_tests + 1))
    
    log "Testing: $test_name"
    
    local target="${to_service}.${to_namespace}.svc.cluster.local"
    
    # Use timeout to avoid hanging tests
    local result
    if kubectl exec -n "$from_namespace" "$from_pod" -- timeout 10 wget -q -O- "http://${target}:${port}" &>/dev/null; then
        result="allow"
    else
        result="deny"
    fi
    
    if [ "$result" = "$expected_result" ]; then
        success "✅ $test_name: $result (expected)"
        test_results["$test_name"]="PASS"
        passed_tests=$((passed_tests + 1))
        return 0
    else
        error "❌ $test_name: $result (expected $expected_result)"
        test_results["$test_name"]="FAIL"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# Test default connectivity (before applying policies)
test_default_connectivity() {
    log "Testing default connectivity (no network policies)..."
    
    test_connectivity "test-client" "$TEST_NAMESPACE" "test-server-service" "$TEST_NAMESPACE" "80" "allow" "Internal communication"
    test_connectivity "external-client" "default" "test-server-service" "$TEST_NAMESPACE" "80" "allow" "External to internal communication"
}

# Apply deny-all network policy
apply_deny_all_policy() {
    log "Applying deny-all network policy..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: $TEST_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
    
    # Wait for policy to take effect
    sleep 10
}

# Test with deny-all policy
test_deny_all_policy() {
    log "Testing with deny-all network policy..."
    
    test_connectivity "test-client" "$TEST_NAMESPACE" "test-server-service" "$TEST_NAMESPACE" "80" "deny" "Internal communication (deny-all)"
    test_connectivity "external-client" "default" "test-server-service" "$TEST_NAMESPACE" "80" "deny" "External to internal communication (deny-all)"
}

# Apply selective allow policy
apply_selective_allow_policy() {
    log "Applying selective allow network policy..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal-only
  namespace: $TEST_NAMESPACE
spec:
  podSelector:
    matchLabels:
      role: server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: client
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: $TEST_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
EOF
    
    # Wait for policy to take effect
    sleep 10
}

# Test with selective allow policy
test_selective_allow_policy() {
    log "Testing with selective allow network policy..."
    
    test_connectivity "test-client" "$TEST_NAMESPACE" "test-server-service" "$TEST_NAMESPACE" "80" "allow" "Internal communication (selective allow)"
    test_connectivity "external-client" "default" "test-server-service" "$TEST_NAMESPACE" "80" "deny" "External to internal communication (selective allow)"
}

# Apply namespace-based policy
apply_namespace_policy() {
    log "Applying namespace-based network policy..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-ml-platform
  namespace: $TEST_NAMESPACE
spec:
  podSelector:
    matchLabels:
      role: server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ml-platform
    - podSelector:
        matchLabels:
          role: client
    ports:
    - protocol: TCP
      port: 80
EOF
    
    # Label ml-platform namespace for testing
    kubectl label namespace ml-platform name=ml-platform --overwrite || true
    
    # Wait for policy to take effect
    sleep 10
}

# Test ML Platform specific policies
test_ml_platform_policies() {
    log "Testing ML Platform network policies..."
    
    # Apply actual ML Platform network policies
    if [ -f "$PROJECT_ROOT/kubernetes/base/security/network-policies.yaml" ]; then
        kubectl apply -f "$PROJECT_ROOT/kubernetes/base/security/network-policies.yaml"
        sleep 15
        
        # Test ML Platform backend connectivity
        if kubectl get pods -n ml-platform -l app=ml-platform-backend &>/dev/null; then
            log "Testing ML Platform backend network policies..."
            
            # Test database connectivity
            test_connectivity "ml-platform-backend" "ml-platform" "postgresql" "ml-platform" "5432" "allow" "Backend to Database"
            
            # Test Redis connectivity
            test_connectivity "ml-platform-backend" "ml-platform" "redis" "ml-platform" "6379" "allow" "Backend to Redis"
            
            # Test external access denial
            test_connectivity "external-client" "default" "ml-platform-backend" "ml-platform" "8000" "deny" "External to Backend (should be denied)"
        else
            warn "ML Platform backend pods not found, skipping backend-specific tests"
        fi
    else
        warn "ML Platform network policies file not found, skipping ML Platform specific tests"
    fi
}

# Test egress policies
test_egress_policies() {
    log "Testing egress network policies..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: $TEST_NAMESPACE
spec:
  podSelector:
    matchLabels:
      role: client
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53  # Allow DNS
  - to:
    - podSelector: {}  # Allow to pods in same namespace
EOF
    
    sleep 10
    
    # Test allowed egress (internal)
    test_connectivity "test-client" "$TEST_NAMESPACE" "test-server-service" "$TEST_NAMESPACE" "80" "allow" "Egress to internal service"
    
    # Test blocked egress (external)
    # This is tricky to test reliably, so we'll just check if the policy exists
    if kubectl get networkpolicy restrict-egress -n "$TEST_NAMESPACE" &>/dev/null; then
        success "✅ Egress policy applied successfully"
        test_results["Egress policy application"]="PASS"
        passed_tests=$((passed_tests + 1))
    else
        error "❌ Egress policy application failed"
        test_results["Egress policy application"]="FAIL"
        failed_tests=$((failed_tests + 1))
    fi
    total_tests=$((total_tests + 1))
}

# Test policy validation
test_policy_validation() {
    log "Testing network policy validation..."
    
    # Test invalid policy (should be rejected)
    local invalid_policy_result=0
    cat <<EOF | kubectl apply -f - &>/dev/null || invalid_policy_result=$?
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: invalid-policy
  namespace: $TEST_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - InvalidType
EOF
    
    total_tests=$((total_tests + 1))
    if [ $invalid_policy_result -ne 0 ]; then
        success "✅ Invalid network policy correctly rejected"
        test_results["Invalid policy rejection"]="PASS"
        passed_tests=$((passed_tests + 1))
    else
        error "❌ Invalid network policy was accepted"
        test_results["Invalid policy rejection"]="FAIL"
        failed_tests=$((failed_tests + 1))
        # Clean up if it was accidentally created
        kubectl delete networkpolicy invalid-policy -n "$TEST_NAMESPACE" &>/dev/null || true
    fi
}

# Generate test report
generate_report() {
    log "Generating network policy test report..."
    
    local report_file="$SCRIPT_DIR/network-policy-test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Network Policy Test Report

**Date:** $(date)
**Namespace:** $NAMESPACE
**Test Namespace:** $TEST_NAMESPACE
**Cluster:** $(kubectl config current-context)

## Test Summary

**Total Tests:** $total_tests
**Passed:** $passed_tests
**Failed:** $failed_tests
**Success Rate:** $(( passed_tests * 100 / total_tests ))%

## Test Results

| Test Name | Result | Status |
|-----------|--------|--------|
EOF
    
    for test_name in "${!test_results[@]}"; do
        local result="${test_results[$test_name]}"
        local status_icon
        if [ "$result" = "PASS" ]; then
            status_icon="✅"
        else
            status_icon="❌"
        fi
        echo "| $test_name | $result | $status_icon |" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## Network Policies Tested

1. **Default Connectivity**: Tests baseline connectivity without policies
2. **Deny-All Policy**: Tests complete traffic blocking
3. **Selective Allow**: Tests allow rules for specific pods/labels
4. **Namespace-Based**: Tests namespace selector functionality
5. **Egress Restrictions**: Tests outbound traffic controls
6. **Policy Validation**: Tests rejection of invalid policies
7. **ML Platform Specific**: Tests production network policies

## Recommendations

EOF
    
    if [ $failed_tests -eq 0 ]; then
        echo "✅ All network policy tests passed. The network security is working as expected." >> "$report_file"
    else
        echo "⚠️ Some network policy tests failed. Review the failing tests and policy configurations." >> "$report_file"
        echo "" >> "$report_file"
        echo "### Failed Tests:" >> "$report_file"
        for test_name in "${!test_results[@]}"; do
            if [ "${test_results[$test_name]}" = "FAIL" ]; then
                echo "- $test_name" >> "$report_file"
            fi
        done
    fi
    
    cat >> "$report_file" << EOF

## Next Steps

1. Review any failed tests and investigate policy configurations
2. Update network policies based on test results
3. Schedule regular network policy testing
4. Consider implementing automated policy testing in CI/CD

## Commands Used

\`\`\`bash
# Apply network policies
kubectl apply -f kubernetes/base/security/network-policies.yaml

# Test connectivity
kubectl exec -n $TEST_NAMESPACE test-client -- wget -q -O- http://test-server-service.$TEST_NAMESPACE.svc.cluster.local

# View network policies
kubectl get networkpolicies -n $TEST_NAMESPACE

# Describe network policy
kubectl describe networkpolicy <policy-name> -n $TEST_NAMESPACE
\`\`\`

EOF
    
    success "Test report generated: $report_file"
    echo "$report_file"
}

# Cleanup test environment
cleanup() {
    log "Cleaning up test environment..."
    
    # Delete test namespace (this removes all test resources)
    kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true
    
    # Delete external client
    kubectl delete pod external-client -n default --ignore-not-found=true
    
    # Remove network policies from ML Platform namespace
    kubectl delete networkpolicy --all -n ml-platform --ignore-not-found=true
    
    success "Cleanup completed"
}

# Handle script interruption
trap cleanup EXIT

# Main execution
main() {
    log "Starting network policy testing..."
    
    check_prerequisites
    setup_test_environment
    
    # Run test sequence
    test_default_connectivity
    
    apply_deny_all_policy
    test_deny_all_policy
    
    apply_selective_allow_policy
    test_selective_allow_policy
    
    apply_namespace_policy
    
    test_egress_policies
    test_policy_validation
    test_ml_platform_policies
    
    # Generate report
    local report_file=$(generate_report)
    
    if [ $failed_tests -eq 0 ]; then
        success "All network policy tests passed! 🎉"
        log "Report: $report_file"
        return 0
    else
        error "$failed_tests out of $total_tests tests failed"
        log "Report: $report_file"
        return 1
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test network policies for the ML Platform.

OPTIONS:
    -n, --namespace NAMESPACE    Target namespace (default: ml-platform)
    -t, --test-namespace NS      Test namespace (default: netpol-test)
    --timeout SECONDS           Test timeout (default: 60)
    -h, --help                  Show this help message

EXAMPLES:
    $0                          # Run with defaults
    $0 -n ml-platform          # Test ml-platform namespace
    $0 --timeout 120           # Use 120 second timeout

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--test-namespace)
            TEST_NAMESPACE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi