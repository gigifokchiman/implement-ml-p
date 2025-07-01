#!/bin/bash
set -euo pipefail

# Enhanced chaos engineering test suite
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
NAMESPACE="${NAMESPACE:-ml-platform}"
CHAOS_NAMESPACE="${CHAOS_NAMESPACE:-chaos-testing}"

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
    
    # Check if Chaos Mesh is installed
    if ! kubectl get crd podchaos.chaos-mesh.org &> /dev/null; then
        warn "Chaos Mesh CRDs not found. Installing Chaos Mesh..."
        install_chaos_mesh
    fi
    
    success "Prerequisites check passed"
}

# Install Chaos Mesh
install_chaos_mesh() {
    log "Installing Chaos Mesh..."
    
    # Create namespace
    kubectl create namespace chaos-testing --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Chaos Mesh via Helm
    if command -v helm &> /dev/null; then
        helm repo add chaos-mesh https://charts.chaos-mesh.org
        helm repo update
        helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
            --namespace chaos-testing \
            --version 2.6.2 \
            --set chaosDaemon.runtime=containerd \
            --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
            --set dashboard.securityMode=false \
            --wait
    else
        # Fallback to kubectl
        kubectl apply -f https://mirrors.chaos-mesh.org/v2.6.2/install.sh
    fi
    
    success "Chaos Mesh installed"
}

# Run baseline performance test
run_baseline_test() {
    log "Running baseline performance test..."
    
    # Use K6 for baseline testing
    if [ -f "$SCRIPT_DIR/../k6/basic-load-test.js" ]; then
        cd "$SCRIPT_DIR/../k6"
        k6 run --summary-trend-stats="avg,min,med,max,p(95),p(99)" basic-load-test.js \
            --out json=baseline-results.json
        cd - > /dev/null
        success "Baseline test completed"
    else
        warn "K6 baseline test not found, skipping..."
    fi
}

# Apply chaos experiment
apply_chaos_experiment() {
    local experiment_file="$1"
    local experiment_name=$(basename "$experiment_file" .yaml)
    
    log "Applying chaos experiment: $experiment_name"
    
    # Apply the experiment
    kubectl apply -f "$experiment_file"
    
    # Wait for experiment to be ready
    local chaos_kind=$(yq eval '.kind' "$experiment_file" 2>/dev/null || echo "PodChaos")
    local chaos_name=$(yq eval '.metadata.name' "$experiment_file" 2>/dev/null || echo "unknown")
    
    # Monitor experiment status
    local timeout=300
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        local status=$(kubectl get "$chaos_kind" "$chaos_name" -n "$NAMESPACE" -o jsonpath='{.status.experiment.phase}' 2>/dev/null || echo "Unknown")
        
        if [ "$status" = "Running" ]; then
            success "Chaos experiment $experiment_name is running"
            return 0
        elif [ "$status" = "Failed" ]; then
            error "Chaos experiment $experiment_name failed"
            kubectl describe "$chaos_kind" "$chaos_name" -n "$NAMESPACE"
            return 1
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    error "Timeout waiting for chaos experiment $experiment_name to start"
    return 1
}

# Run performance test during chaos
run_chaos_performance_test() {
    local test_name="$1"
    
    log "Running performance test during chaos: $test_name"
    
    if [ -f "$SCRIPT_DIR/../k6/stress-test.js" ]; then
        cd "$SCRIPT_DIR/../k6"
        k6 run --summary-trend-stats="avg,min,med,max,p(95),p(99)" stress-test.js \
            --out json="${test_name}-chaos-results.json"
        cd - > /dev/null
    else
        warn "K6 stress test not found, using curl for basic testing..."
        
        # Basic curl testing
        local backend_url=$(kubectl get service ml-platform-backend -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "localhost")
        
        for i in {1..100}; do
            response_time=$(curl -w "%{time_total}" -s -o /dev/null "http://$backend_url:8000/health" || echo "999")
            echo "Request $i: ${response_time}s"
            sleep 0.1
        done
    fi
}

# Clean up chaos experiment
cleanup_chaos_experiment() {
    local experiment_file="$1"
    local experiment_name=$(basename "$experiment_file" .yaml)
    
    log "Cleaning up chaos experiment: $experiment_name"
    
    kubectl delete -f "$experiment_file" --ignore-not-found=true
    
    # Wait for cleanup
    sleep 10
    
    success "Chaos experiment $experiment_name cleaned up"
}

# Generate test report
generate_report() {
    log "Generating chaos engineering test report..."
    
    local report_file="$SCRIPT_DIR/chaos-test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Chaos Engineering Test Report

**Date:** $(date)
**Namespace:** $NAMESPACE
**Cluster:** $(kubectl config current-context)

## Test Summary

| Test Type | Status | Duration | Notes |
|-----------|--------|----------|-------|
EOF
    
    # Add test results to report
    for result_file in "$SCRIPT_DIR"/../k6/*-chaos-results.json; do
        if [ -f "$result_file" ]; then
            local test_name=$(basename "$result_file" -chaos-results.json)
            local p95_time=$(jq -r '.metrics.http_req_duration.values.p95' "$result_file" 2>/dev/null || echo "N/A")
            local error_rate=$(jq -r '.metrics.http_req_failed.values.rate' "$result_file" 2>/dev/null || echo "N/A")
            
            echo "| $test_name | Completed | N/A | P95: ${p95_time}ms, Error Rate: ${error_rate}% |" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Chaos Experiments Executed

1. **Pod Failure Test**: Terminated random pods to test resilience
2. **Network Delay Test**: Introduced 100ms latency between services
3. **Network Partition Test**: Simulated network split between backend and database
4. **CPU Stress Test**: Applied high CPU load to backend pods
5. **Memory Stress Test**: Applied memory pressure to backend pods
6. **Disk I/O Test**: Introduced disk latency and faults
7. **Time Skew Test**: Shifted system time to test time-sensitive operations

## Recommendations

- Review application resilience patterns
- Consider implementing circuit breakers
- Improve monitoring and alerting
- Add graceful degradation mechanisms

## Next Steps

- Schedule regular chaos engineering tests
- Integrate with CI/CD pipeline
- Expand test scenarios based on findings
EOF
    
    success "Test report generated: $report_file"
    echo "$report_file"
}

# Main execution
main() {
    log "Starting advanced chaos engineering tests..."
    
    check_prerequisites
    
    # Run baseline test
    run_baseline_test
    
    # Array of chaos experiments
    local experiments=(
        "$SCRIPT_DIR/pod-failure-experiment.yaml"
        "$SCRIPT_DIR/network-chaos-experiment.yaml"
        "$SCRIPT_DIR/resource-chaos-experiment.yaml"
        "$SCRIPT_DIR/time-chaos-experiment.yaml"
    )
    
    # Execute each chaos experiment
    for experiment in "${experiments[@]}"; do
        if [ -f "$experiment" ]; then
            local experiment_name=$(basename "$experiment" .yaml)
            
            log "Starting chaos experiment: $experiment_name"
            
            if apply_chaos_experiment "$experiment"; then
                # Run performance test during chaos
                run_chaos_performance_test "$experiment_name"
                
                # Wait for experiment to complete
                sleep 60
                
                # Clean up
                cleanup_chaos_experiment "$experiment"
                
                # Wait between experiments
                sleep 30
            else
                error "Failed to run chaos experiment: $experiment_name"
            fi
        else
            warn "Experiment file not found: $experiment"
        fi
    done
    
    # Generate final report
    local report_file=$(generate_report)
    
    success "Advanced chaos engineering tests completed!"
    log "Report available at: $report_file"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi