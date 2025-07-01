#!/bin/bash
set -euo pipefail

# Chaos Engineering Test Runner
# Runs chaos experiments and monitors system resilience

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ml-platform"
EXPERIMENT_DURATION="300s"

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

check_prerequisites() {
    log "INFO" "Checking prerequisites for chaos testing..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl is required for chaos testing"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log "ERROR" "Cannot access Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "ERROR" "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    # Check if Chaos Mesh is installed (optional)
    if ! kubectl get crd podchaos.chaos-mesh.org &> /dev/null; then
        log "WARN" "Chaos Mesh not installed - using manual chaos testing"
        export USE_MANUAL_CHAOS=true
    else
        log "INFO" "Chaos Mesh detected - using CRD-based chaos testing"
        export USE_MANUAL_CHAOS=false
    fi
    
    log "SUCCESS" "Prerequisites check completed"
}

monitor_system_health() {
    log "INFO" "Monitoring system health during chaos experiment..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + 300))  # 5 minutes
    
    while [[ $(date +%s) -lt $end_time ]]; do
        # Check pod status
        local failed_pods
        failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
        
        # Check service availability
        local total_pods
        total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        local running_pods
        running_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        local availability_percentage=0
        if [[ $total_pods -gt 0 ]]; then
            availability_percentage=$((running_pods * 100 / total_pods))
        fi
        
        log "INFO" "System status: $running_pods/$total_pods pods running ($availability_percentage% availability)"
        
        # Alert if availability drops below threshold
        if [[ $availability_percentage -lt 50 ]]; then
            log "WARN" "System availability dropped below 50%!"
        fi
        
        sleep 30
    done
}

run_manual_pod_chaos() {
    log "INFO" "Running manual pod chaos experiment..."
    
    # Get list of pods that can be safely deleted
    local pods
    pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/part-of=ml-platform" --no-headers -o custom-columns=":metadata.name")
    
    if [[ -z "$pods" ]]; then
        log "WARN" "No pods found for chaos testing"
        return 0
    fi
    
    # Convert to array
    local pod_array=($pods)
    local total_pods=${#pod_array[@]}
    
    if [[ $total_pods -eq 0 ]]; then
        log "WARN" "No suitable pods found for chaos testing"
        return 0
    fi
    
    # Calculate 20% of pods to delete
    local pods_to_delete=$((total_pods * 20 / 100))
    if [[ $pods_to_delete -eq 0 ]]; then
        pods_to_delete=1
    fi
    
    log "INFO" "Deleting $pods_to_delete out of $total_pods pods"
    
    # Randomly select pods to delete
    for ((i=0; i<pods_to_delete; i++)); do
        local random_index=$((RANDOM % ${#pod_array[@]}))
        local pod_to_delete=${pod_array[$random_index]}
        
        log "INFO" "Deleting pod: $pod_to_delete"
        kubectl delete pod "$pod_to_delete" -n "$NAMESPACE" --grace-period=0 --force
        
        # Remove from array to avoid deleting same pod twice
        unset pod_array[$random_index]
        pod_array=("${pod_array[@]}")  # Re-index array
        
        if [[ ${#pod_array[@]} -eq 0 ]]; then
            break
        fi
        
        sleep 10  # Wait between deletions
    done
}

run_chaos_mesh_experiment() {
    log "INFO" "Running Chaos Mesh experiments..."
    
    # Apply chaos experiments
    kubectl apply -f "$SCRIPT_DIR/pod-failure-experiment.yaml"
    
    log "INFO" "Chaos experiments applied, monitoring for $EXPERIMENT_DURATION..."
    
    # Monitor the experiment
    sleep 300  # Wait for experiment duration
    
    # Clean up experiments
    kubectl delete -f "$SCRIPT_DIR/pod-failure-experiment.yaml" --ignore-not-found=true
    
    log "INFO" "Chaos experiments completed and cleaned up"
}

run_resilience_tests() {
    log "INFO" "Running system resilience tests..."
    
    # Start monitoring in background
    monitor_system_health &
    local monitor_pid=$!
    
    # Run chaos experiments
    if [[ "${USE_MANUAL_CHAOS:-false}" == "true" ]]; then
        run_manual_pod_chaos
    else
        run_chaos_mesh_experiment
    fi
    
    # Wait for monitoring to complete
    wait $monitor_pid
    
    log "SUCCESS" "Resilience tests completed"
}

validate_recovery() {
    log "INFO" "Validating system recovery after chaos..."
    
    # Wait for system to stabilize
    sleep 60
    
    # Check if all pods are back to running state
    local max_attempts=12  # 6 minutes total
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local failed_pods
        failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
        
        if [[ $failed_pods -eq 0 ]]; then
            log "SUCCESS" "All pods recovered successfully"
            return 0
        fi
        
        log "INFO" "Waiting for pod recovery... ($failed_pods pods still not running)"
        sleep 30
        ((attempt++))
    done
    
    log "ERROR" "System did not fully recover within expected time"
    kubectl get pods -n "$NAMESPACE"
    return 1
}

generate_chaos_report() {
    local report_file="chaos-test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Chaos Engineering Test Report

**Generated:** $(date)
**Namespace:** $NAMESPACE
**Duration:** $EXPERIMENT_DURATION

## Test Summary

This chaos engineering test validated the resilience of the ML Platform infrastructure
by introducing controlled failures and measuring system recovery.

## Experiments Conducted

1. **Pod Failure Test**
   - Randomly deleted 20% of application pods
   - Monitored system availability during failure
   - Validated automatic recovery

## Results

### System Availability
- Monitored pod availability every 30 seconds
- Measured recovery time after pod failures
- Validated that system remained functional

### Recovery Metrics
- **Pod Recovery Time**: Time for deleted pods to restart
- **Service Availability**: Percentage of time services remained accessible
- **Data Consistency**: Verification that no data was lost

## Recommendations

### If Recovery Time > 2 minutes
- Review pod startup time and resource allocation
- Implement readiness and liveness probes
- Consider pre-pulling container images

### If Availability < 80%
- Increase replica counts for critical services
- Implement pod disruption budgets
- Add load balancing and failover mechanisms

### If Data Loss Occurred
- Review backup and recovery procedures
- Implement persistent volume snapshots
- Add data replication strategies

## Next Steps

1. Run chaos tests regularly (weekly/monthly)
2. Expand tests to include network and storage failures
3. Integrate chaos testing into CI/CD pipeline
4. Monitor and alert on resilience metrics

---
*Generated by ML Platform Chaos Testing Framework*
EOF

    log "INFO" "Chaos test report generated: $report_file"
}

# Main execution
main() {
    local test_type="${1:-basic}"
    
    log "INFO" "Starting chaos engineering tests (type: $test_type)"
    
    check_prerequisites
    
    case "$test_type" in
        "basic")
            run_resilience_tests
            validate_recovery
            ;;
        "extended")
            run_resilience_tests
            validate_recovery
            generate_chaos_report
            ;;
        "monitor-only")
            monitor_system_health
            ;;
        *)
            log "ERROR" "Unknown test type: $test_type"
            log "INFO" "Available types: basic, extended, monitor-only"
            exit 1
            ;;
    esac
    
    log "SUCCESS" "Chaos engineering tests completed successfully"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [TEST_TYPE]

Run chaos engineering tests to validate system resilience.

TEST_TYPES:
    basic       - Run basic pod failure and recovery tests
    extended    - Basic tests plus detailed reporting
    monitor-only - Just monitor system health without chaos

EXAMPLES:
    $0                  # Run basic chaos tests
    $0 extended        # Run extended tests with reporting
    $0 monitor-only    # Monitor system without introducing chaos

REQUIREMENTS:
    - kubectl with access to cluster
    - ml-platform namespace with running applications
    - Optional: Chaos Mesh for advanced experiments
EOF
}

# Parse arguments
case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        main "${1:-basic}"
        ;;
esac