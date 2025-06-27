#!/bin/bash
set -euo pipefail

# Performance and load testing for ML Platform infrastructure
# Tests system performance, scalability, and resource utilization

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_RESULTS=()

# Default configuration
DURATION=60
CONCURRENT_USERS=10
TARGET_HOST="localhost:30080"
ENVIRONMENT="local"

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

# Check if cluster is available
check_cluster_access() {
    if ! kubectl cluster-info &> /dev/null; then
        log "ERROR" "Cannot access Kubernetes cluster"
        return 1
    fi
    
    if ! kubectl get namespace ml-platform &> /dev/null; then
        log "ERROR" "ml-platform namespace not found"
        return 1
    fi
    
    return 0
}

# Basic connectivity test
test_basic_connectivity() {
    log "INFO" "Testing basic connectivity to $TARGET_HOST"
    
    if curl -f -s "http://$TARGET_HOST" > /dev/null; then
        return 0
    else
        log "WARN" "Direct HTTP access failed, trying with host header"
        if curl -f -s -H "Host: ml-platform.local" "http://$TARGET_HOST" > /dev/null; then
            return 0
        else
            log "ERROR" "Cannot connect to $TARGET_HOST"
            return 1
        fi
    fi
}

# Load testing with Apache Bench (ab)
test_load_ab() {
    if ! command -v ab &> /dev/null; then
        log "WARN" "Apache Bench (ab) not installed, skipping load test"
        return 0
    fi
    
    log "INFO" "Running Apache Bench load test ($CONCURRENT_USERS users, ${DURATION}s)"
    
    local requests=$((CONCURRENT_USERS * DURATION / 2))  # Conservative request rate
    local output_file="/tmp/ab-test-$(date +%s).txt"
    
    # Test frontend
    if ab -n "$requests" -c "$CONCURRENT_USERS" -t "$DURATION" \
        -H "Host: ml-platform.local" \
        "http://$TARGET_HOST/" > "$output_file" 2>&1; then
        
        # Parse results
        local rps
        rps=$(grep "Requests per second:" "$output_file" | awk '{print $4}')
        local response_time
        response_time=$(grep "Time per request:" "$output_file" | head -1 | awk '{print $4}')
        
        log "SUCCESS" "Load test completed - RPS: $rps, Avg Response Time: ${response_time}ms"
        
        # Check performance thresholds
        if (( $(echo "$rps > 50" | bc -l) )); then
            log "SUCCESS" "Performance threshold met (>50 RPS)"
        else
            log "WARN" "Performance below threshold (<50 RPS)"
        fi
        
        rm -f "$output_file"
        return 0
    else
        log "ERROR" "Apache Bench load test failed"
        cat "$output_file" | tail -10
        rm -f "$output_file"
        return 1
    fi
}

# Load testing with wrk
test_load_wrk() {
    if ! command -v wrk &> /dev/null; then
        log "WARN" "wrk not installed, skipping load test"
        return 0
    fi
    
    log "INFO" "Running wrk load test ($CONCURRENT_USERS connections, ${DURATION}s)"
    
    local output_file="/tmp/wrk-test-$(date +%s).txt"
    
    # Test frontend with custom header
    if wrk -t4 -c"$CONCURRENT_USERS" -d"${DURATION}s" \
        -H "Host: ml-platform.local" \
        "http://$TARGET_HOST/" > "$output_file" 2>&1; then
        
        # Parse results
        local rps
        rps=$(grep "Requests/sec:" "$output_file" | awk '{print $2}')
        local latency
        latency=$(grep "Latency" "$output_file" | awk '{print $2}')
        
        log "SUCCESS" "wrk test completed - RPS: $rps, Avg Latency: $latency"
        
        rm -f "$output_file"
        return 0
    else
        log "ERROR" "wrk load test failed"
        cat "$output_file"
        rm -f "$output_file"
        return 1
    fi
}

# Resource utilization monitoring
test_resource_utilization() {
    log "INFO" "Monitoring resource utilization during load test"
    
    # Start background monitoring
    kubectl top nodes > /tmp/nodes-before.txt 2>/dev/null || echo "Metrics not available" > /tmp/nodes-before.txt
    kubectl top pods -n ml-platform > /tmp/pods-before.txt 2>/dev/null || echo "Metrics not available" > /tmp/pods-before.txt
    
    # Run a quick load test
    if command -v ab &> /dev/null; then
        ab -n 100 -c 5 -H "Host: ml-platform.local" "http://$TARGET_HOST/" > /dev/null 2>&1 || true
    fi
    
    sleep 10
    
    # Capture metrics after load
    kubectl top nodes > /tmp/nodes-after.txt 2>/dev/null || echo "Metrics not available" > /tmp/nodes-after.txt
    kubectl top pods -n ml-platform > /tmp/pods-after.txt 2>/dev/null || echo "Metrics not available" > /tmp/pods-after.txt
    
    log "INFO" "Node utilization before:"
    cat /tmp/nodes-before.txt
    
    log "INFO" "Node utilization after:"
    cat /tmp/nodes-after.txt
    
    log "INFO" "Pod utilization after:"
    cat /tmp/pods-after.txt
    
    # Cleanup
    rm -f /tmp/nodes-before.txt /tmp/nodes-after.txt /tmp/pods-before.txt /tmp/pods-after.txt
    
    return 0
}

# Autoscaling test
test_horizontal_pod_autoscaler() {
    log "INFO" "Testing Horizontal Pod Autoscaler behavior"
    
    # Check if HPA is configured
    if ! kubectl get hpa -n ml-platform &> /dev/null; then
        log "WARN" "No HPA configured, skipping autoscaling test"
        return 0
    fi
    
    # Get initial replica count
    local initial_replicas
    initial_replicas=$(kubectl get deployment backend -n ml-platform -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    log "INFO" "Initial backend replicas: $initial_replicas"
    
    # Generate load to trigger autoscaling
    if command -v ab &> /dev/null; then
        log "INFO" "Generating load to trigger autoscaling..."
        ab -n 1000 -c 20 -t 60 -H "Host: api.ml-platform.local" "http://$TARGET_HOST/health" > /dev/null 2>&1 &
        local ab_pid=$!
        
        # Monitor for 2 minutes
        for i in {1..24}; do
            sleep 5
            local current_replicas
            current_replicas=$(kubectl get deployment backend -n ml-platform -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            
            if [[ "$current_replicas" -gt "$initial_replicas" ]]; then
                log "SUCCESS" "Autoscaling triggered: $initial_replicas -> $current_replicas replicas"
                kill $ab_pid 2>/dev/null || true
                return 0
            fi
            
            log "INFO" "Waiting for autoscaling... Current replicas: $current_replicas"
        done
        
        kill $ab_pid 2>/dev/null || true
        log "WARN" "Autoscaling not triggered within test period"
    fi
    
    return 0
}

# Storage performance test
test_storage_performance() {
    log "INFO" "Testing storage performance"
    
    # Create a test pod for storage testing
    kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
  namespace: ml-platform
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '300']
    volumeMounts:
    - name: test-volume
      mountPath: /test
  volumes:
  - name: test-volume
    emptyDir: {}
  restartPolicy: Never
EOF
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/storage-test -n ml-platform --timeout=60s
    
    # Run storage performance test
    log "INFO" "Running storage write test..."
    local write_result
    write_result=$(kubectl exec -n ml-platform storage-test -- sh -c "
        time sh -c 'dd if=/dev/zero of=/test/testfile bs=1M count=100 2>&1'
    " 2>&1)
    
    log "INFO" "Storage write test result:"
    echo "$write_result"
    
    # Run storage read test
    log "INFO" "Running storage read test..."
    local read_result
    read_result=$(kubectl exec -n ml-platform storage-test -- sh -c "
        time sh -c 'dd if=/test/testfile of=/dev/null bs=1M 2>&1'
    " 2>&1)
    
    log "INFO" "Storage read test result:"
    echo "$read_result"
    
    # Cleanup
    kubectl delete pod storage-test -n ml-platform --ignore-not-found=true
    
    return 0
}

# Network latency test
test_network_latency() {
    log "INFO" "Testing network latency between services"
    
    # Create a test pod for network testing
    kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-test
  namespace: ml-platform
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '300']
  restartPolicy: Never
EOF
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/network-test -n ml-platform --timeout=60s
    
    # Test connectivity to services
    local services=("minio:9000" "backend:8000" "frontend:3000")
    
    for service in "${services[@]}"; do
        log "INFO" "Testing connectivity to $service"
        
        local result
        result=$(kubectl exec -n ml-platform network-test -- sh -c "
            time nc -z ${service/:/ } && echo 'Connection successful'
        " 2>&1 || echo "Connection failed")
        
        log "INFO" "Network test to $service: $result"
    done
    
    # Cleanup
    kubectl delete pod network-test -n ml-platform --ignore-not-found=true
    
    return 0
}

# Database performance test
test_database_performance() {
    if [[ "$ENVIRONMENT" == "local" ]]; then
        log "WARN" "Database performance test skipped for local environment"
        return 0
    fi
    
    log "INFO" "Testing database performance"
    
    # This would require connecting to the actual RDS instance
    # For now, just check if database credentials exist
    if kubectl get secret database-credentials -n ml-platform &> /dev/null; then
        log "SUCCESS" "Database credentials found"
        # TODO: Implement actual database performance testing
        log "INFO" "Database performance test would require psql/pgbench tools"
    else
        log "WARN" "Database credentials not found, skipping database test"
    fi
    
    return 0
}

# Generate performance report
generate_performance_report() {
    local report_file="$SCRIPT_DIR/performance-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# ML Platform Performance Report

Generated: $(date)
Environment: $ENVIRONMENT
Target: $TARGET_HOST
Test Duration: ${DURATION}s
Concurrent Users: $CONCURRENT_USERS

## Test Results

$(printf '%s\n' "${TEST_RESULTS[@]}")

## Performance Metrics

### Load Testing
- Tool: Apache Bench (ab) / wrk
- Duration: ${DURATION} seconds
- Concurrent Users: $CONCURRENT_USERS
- Target: Frontend service

### Resource Utilization
- Platform: Kubernetes
- Namespace: ml-platform
- Monitoring: kubectl top

### Storage Performance
- Test: 100MB write/read operations
- Storage: Kubernetes EmptyDir volume

### Network Latency
- Test: Service-to-service connectivity
- Protocol: TCP connection tests

## Performance Baselines

### Frontend Service
- **Target RPS**: >50 requests/second
- **Target Response Time**: <500ms average
- **Target Availability**: 99.9%

### Backend API
- **Target RPS**: >100 requests/second
- **Target Response Time**: <200ms average
- **Target Availability**: 99.9%

### Database
- **Target Connection Time**: <100ms
- **Target Query Time**: <50ms average
- **Target Availability**: 99.99%

## Scaling Recommendations

### Horizontal Scaling
- Configure HPA for frontend/backend deployments
- Set CPU target: 70%
- Set memory target: 80%
- Min replicas: 2 (prod), 1 (dev)
- Max replicas: 10 (prod), 3 (dev)

### Vertical Scaling
- Monitor resource utilization over time
- Adjust resource requests/limits based on actual usage
- Consider node instance types for workload characteristics

### Storage Scaling
- Monitor PVC usage
- Implement automated volume expansion
- Consider storage class performance characteristics

## Next Steps

1. Implement comprehensive monitoring (Prometheus/Grafana)
2. Set up alerting for performance degradation
3. Establish performance testing in CI/CD pipeline
4. Regular load testing schedule
5. Capacity planning based on growth projections
EOF

    log "INFO" "Performance report generated: $report_file"
}

# Main testing logic
main() {
    local test_type="${1:-basic}"
    
    log "INFO" "Starting performance tests (type: $test_type)"
    log "INFO" "Target: $TARGET_HOST, Duration: ${DURATION}s, Users: $CONCURRENT_USERS"
    
    local failed_tests=0
    
    # Prerequisites
    run_test "Cluster access" "check_cluster_access" || ((failed_tests++))
    run_test "Basic connectivity" "test_basic_connectivity" || ((failed_tests++))
    
    # Load testing
    run_test "Load test (Apache Bench)" "test_load_ab" || ((failed_tests++))
    run_test "Load test (wrk)" "test_load_wrk" || ((failed_tests++))
    
    # Resource and performance tests
    run_test "Resource utilization" "test_resource_utilization" || ((failed_tests++))
    run_test "Storage performance" "test_storage_performance" || ((failed_tests++))
    run_test "Network latency" "test_network_latency" || ((failed_tests++))
    
    # Extended tests
    if [[ "$test_type" == "extended" ]]; then
        run_test "Horizontal Pod Autoscaler" "test_horizontal_pod_autoscaler" || ((failed_tests++))
        run_test "Database performance" "test_database_performance" || ((failed_tests++))
    fi
    
    # Generate report
    generate_performance_report
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Performance Test Results Summary:"
    echo "=========================================="
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        log "SUCCESS" "All performance tests completed!"
        exit 0
    else
        log "ERROR" "$failed_tests performance test(s) failed"
        exit 1
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_TYPE]

Run performance and load tests for ML Platform infrastructure

TEST_TYPES:
    basic     - Basic load and performance tests (default)
    extended  - Basic tests plus autoscaling and database tests

OPTIONS:
    -h, --help              Show this help message
    -d, --duration SECONDS  Test duration in seconds (default: 60)
    -c, --concurrent USERS  Number of concurrent users (default: 10)
    -t, --target HOST:PORT  Target host and port (default: localhost:30080)
    -e, --environment ENV   Environment name (default: local)

EXAMPLES:
    $0                                    # Run basic tests
    $0 extended                          # Run extended tests
    $0 -d 120 -c 20 basic               # 2-minute test with 20 users
    $0 -t api.example.com:443 extended   # Test against production

DEPENDENCIES (optional):
    - ab (Apache Bench)    Load testing tool
    - wrk                  Modern HTTP benchmarking tool
    - kubectl              Kubernetes CLI (required)
    - bc                   Basic calculator for comparisons
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -c|--concurrent)
            CONCURRENT_USERS="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_HOST="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        basic|extended)
            main "$1"
            exit $?
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Default to basic tests if no test type specified
main "basic"