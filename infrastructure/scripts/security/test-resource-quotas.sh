#!/bin/bash
# Test Resource Quota Enforcement
# This script validates that team resource quotas properly reject requests that exceed limits

set -e

echo "🧪 Testing Resource Quota Enforcement"
echo "====================================="

# Parse arguments
ENVIRONMENT=${1:-local}
CLUSTER_CONTEXT=""

case $ENVIRONMENT in
  "local")
    CLUSTER_CONTEXT="kind-data-platform-local"
    ;;
  "dev"|"staging"|"prod")
    CLUSTER_CONTEXT="$ENVIRONMENT-cluster-context"
    ;;
  *)
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [local|dev|staging|prod]"
    exit 1
    ;;
esac

echo "📋 Environment: $ENVIRONMENT"
echo "📋 Target cluster: $CLUSTER_CONTEXT"

# Switch to target cluster
kubectl config use-context $CLUSTER_CONTEXT

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper function to test quota enforcement
test_quota_enforcement() {
    local namespace=$1
    local pod_name=$2
    local cpu_request=$3
    local memory_request=$4
    local should_succeed=$5
    local description=$6
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${YELLOW}Testing: $description${NC}"
    echo "  Namespace: $namespace"
    echo "  CPU Request: $cpu_request"
    echo "  Memory Request: $memory_request"
    
    # Create pod with specified resources
    if kubectl run $pod_name --image=nginx -n $namespace \
        --overrides="{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx\",\"resources\":{\"requests\":{\"cpu\":\"$cpu_request\",\"memory\":\"$memory_request\"},\"limits\":{\"cpu\":\"$cpu_request\",\"memory\":\"$memory_request\"}}}]}}" \
        --dry-run=server &>/dev/null; then
        
        if [ "$should_succeed" = "true" ]; then
            echo -e "  ${GREEN}✅ PASS: Pod creation allowed (expected)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "  ${RED}❌ FAIL: Pod creation allowed (should be blocked by quota)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [ "$should_succeed" = "false" ]; then
            echo -e "  ${GREEN}✅ PASS: Pod creation blocked by quota (expected)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "  ${RED}❌ FAIL: Pod creation blocked (should be allowed)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

# Helper function to show current quota usage
show_quota_usage() {
    local namespace=$1
    local quota_name=$2
    
    echo -e "\n${BLUE}📊 Current quota usage in $namespace:${NC}"
    kubectl describe quota $quota_name -n $namespace | grep -E "(Resource|requests\.cpu|requests\.memory|limits\.cpu|limits\.memory)"
}

# Set environment-specific quota values
if [ "$ENVIRONMENT" = "local" ]; then
    # Local development quotas (smaller for local testing)
    ML_CPU_QUOTA="2"
    ML_MEMORY_QUOTA="4Gi"
    DATA_CPU_QUOTA="1"
    DATA_MEMORY_QUOTA="2Gi"
    CORE_CPU_QUOTA="1"
    CORE_MEMORY_QUOTA="2Gi"
else
    # Production quotas
    ML_CPU_QUOTA="20"
    ML_MEMORY_QUOTA="64Gi"
    DATA_CPU_QUOTA="16"
    DATA_MEMORY_QUOTA="48Gi"
    CORE_CPU_QUOTA="8"
    CORE_MEMORY_QUOTA="24Gi"
fi

echo ""
echo "1️⃣ Testing ML Team Quotas (app-ml-team) - $ENVIRONMENT environment"
echo "----------------------------------------------------------------------"
echo "Expected quotas: CPU=${ML_CPU_QUOTA}, Memory=${ML_MEMORY_QUOTA}"

show_quota_usage "app-ml-team" "ml-team-quota"

if [ "$ENVIRONMENT" = "local" ]; then
    # Test cases for ML team (local: 2 CPU, 4Gi memory quota)
    test_quota_enforcement "app-ml-team" "test-small" "100m" "256Mi" "true" "Small pod within quota"
    test_quota_enforcement "app-ml-team" "test-large-cpu" "3" "1Gi" "false" "Pod exceeding CPU quota (3 > ${ML_CPU_QUOTA})"
    test_quota_enforcement "app-ml-team" "test-large-memory" "100m" "5Gi" "false" "Pod exceeding memory quota (5Gi > ${ML_MEMORY_QUOTA})"
    test_quota_enforcement "app-ml-team" "test-max-container" "1" "2Gi" "true" "Pod within limits"
else
    # Test cases for ML team (production: 20 CPU, 64Gi memory quota)
    test_quota_enforcement "app-ml-team" "test-small" "1" "1Gi" "true" "Small pod within quota"
    test_quota_enforcement "app-ml-team" "test-large-cpu" "25" "1Gi" "false" "Pod exceeding CPU quota (25 > ${ML_CPU_QUOTA})"
    test_quota_enforcement "app-ml-team" "test-large-memory" "1" "70Gi" "false" "Pod exceeding memory quota (70Gi > ${ML_MEMORY_QUOTA})"
    test_quota_enforcement "app-ml-team" "test-max-container" "4" "8Gi" "true" "Pod at LimitRange maximum"
fi

echo ""
echo "2️⃣ Testing Data Team Quotas (app-data-team) - $ENVIRONMENT environment"
echo "-----------------------------------------------------------------------"
echo "Expected quotas: CPU=${DATA_CPU_QUOTA}, Memory=${DATA_MEMORY_QUOTA}"

show_quota_usage "app-data-team" "data-team-quota"

if [ "$ENVIRONMENT" = "local" ]; then
    # Test cases for Data team (local: 1 CPU, 2Gi memory quota)
    test_quota_enforcement "app-data-team" "test-small" "100m" "256Mi" "true" "Small pod within quota"
    test_quota_enforcement "app-data-team" "test-large-cpu" "2" "1Gi" "false" "Pod exceeding CPU quota (2 > ${DATA_CPU_QUOTA})"
    test_quota_enforcement "app-data-team" "test-large-memory" "100m" "3Gi" "false" "Pod exceeding memory quota (3Gi > ${DATA_MEMORY_QUOTA})"
    test_quota_enforcement "app-data-team" "test-max-container" "500m" "1Gi" "true" "Pod within limits"
else
    # Test cases for Data team (production: 16 CPU, 48Gi memory quota)
    test_quota_enforcement "app-data-team" "test-small" "1" "1Gi" "true" "Small pod within quota"
    test_quota_enforcement "app-data-team" "test-large-cpu" "20" "1Gi" "false" "Pod exceeding CPU quota (20 > ${DATA_CPU_QUOTA})"
    test_quota_enforcement "app-data-team" "test-large-memory" "1" "50Gi" "false" "Pod exceeding memory quota (50Gi > ${DATA_MEMORY_QUOTA})"
    test_quota_enforcement "app-data-team" "test-max-container" "3" "6Gi" "true" "Pod at LimitRange maximum"
fi

echo ""
echo "3️⃣ Testing Core Team Quotas (app-core-team) - $ENVIRONMENT environment"
echo "-----------------------------------------------------------------------"
echo "Expected quotas: CPU=${CORE_CPU_QUOTA}, Memory=${CORE_MEMORY_QUOTA}"

show_quota_usage "app-core-team" "core-team-quota"

if [ "$ENVIRONMENT" = "local" ]; then
    # Test cases for Core team (local: 1 CPU, 2Gi memory quota)
    test_quota_enforcement "app-core-team" "test-small" "100m" "256Mi" "true" "Small pod within quota"
    test_quota_enforcement "app-core-team" "test-large-cpu" "2" "1Gi" "false" "Pod exceeding CPU quota (2 > ${CORE_CPU_QUOTA})"
    test_quota_enforcement "app-core-team" "test-large-memory" "100m" "3Gi" "false" "Pod exceeding memory quota (3Gi > ${CORE_MEMORY_QUOTA})"
    test_quota_enforcement "app-core-team" "test-max-container" "500m" "1Gi" "true" "Pod within limits"
else
    # Test cases for Core team (production: 8 CPU, 24Gi memory quota)
    test_quota_enforcement "app-core-team" "test-small" "1" "1Gi" "true" "Small pod within quota"
    test_quota_enforcement "app-core-team" "test-large-cpu" "10" "1Gi" "false" "Pod exceeding CPU quota (10 > ${CORE_CPU_QUOTA})"
    test_quota_enforcement "app-core-team" "test-large-memory" "1" "25Gi" "false" "Pod exceeding memory quota (25Gi > ${CORE_MEMORY_QUOTA})"
    test_quota_enforcement "app-core-team" "test-max-container" "2" "4Gi" "true" "Pod at LimitRange maximum"
fi

echo ""
echo "4️⃣ Testing Multi-Pod Quota Exhaustion - $ENVIRONMENT environment"
echo "----------------------------------------------------------------"

echo -e "\n${YELLOW}Testing: Multiple pods exhausting ML team CPU quota${NC}"

# Create pods that together will exceed the quota
echo "Creating pods to approach quota limit..."

if [ "$ENVIRONMENT" = "local" ]; then
    # For local: Create 2 pods with 800m CPU each = 1.6 CPU total (out of 2 CPU quota)
    for i in {1..2}; do
        kubectl run quota-test-$i --image=nginx -n app-ml-team \
            --overrides="{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx\",\"resources\":{\"requests\":{\"cpu\":\"800m\",\"memory\":\"1Gi\"},\"limits\":{\"cpu\":\"800m\",\"memory\":\"1Gi\"}}}]}}" \
            &>/dev/null || echo "Pod quota-test-$i failed to create"
    done
    
    echo "Waiting for pods to be created..."
    sleep 3
    
    show_quota_usage "app-ml-team" "ml-team-quota"
    
    echo -e "\n${YELLOW}Now testing: Pod that would exceed quota${NC}"
    
    # This should fail - would bring total to over 2 CPU
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if kubectl run quota-test-3 --image=nginx -n app-ml-team \
        --overrides="{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx\",\"resources\":{\"requests\":{\"cpu\":\"800m\",\"memory\":\"1Gi\"},\"limits\":{\"cpu\":\"800m\",\"memory\":\"1Gi\"}}}]}}" \
        --dry-run=server &>/dev/null; then
        echo -e "${RED}❌ FAIL: Third pod allowed (should exceed quota)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    else
        echo -e "${GREEN}✅ PASS: Third pod correctly blocked by quota${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
    
    echo ""
    echo "🧹 Cleaning up test pods..."
    kubectl delete pod quota-test-1 quota-test-2 -n app-ml-team &>/dev/null || echo "Some test pods may not exist"
else
    # For production: Create 4 pods with 4 CPU each = 16 CPU total (out of 20 CPU quota)
    for i in {1..4}; do
        kubectl run quota-test-$i --image=nginx -n app-ml-team \
            --overrides="{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx\",\"resources\":{\"requests\":{\"cpu\":\"4\",\"memory\":\"1Gi\"},\"limits\":{\"cpu\":\"4\",\"memory\":\"1Gi\"}}}]}}" \
            &>/dev/null || echo "Pod quota-test-$i failed to create"
    done
    
    echo "Waiting for pods to be created..."
    sleep 3
    
    show_quota_usage "app-ml-team" "ml-team-quota"
    
    echo -e "\n${YELLOW}Now testing: Pod that would exceed quota${NC}"
    
    # This should fail - would bring total to 20 CPU (at limit but with existing 100m usage = over limit)
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if kubectl run quota-test-5 --image=nginx -n app-ml-team \
        --overrides="{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"image\":\"nginx\",\"resources\":{\"requests\":{\"cpu\":\"4\",\"memory\":\"1Gi\"},\"limits\":{\"cpu\":\"4\",\"memory\":\"1Gi\"}}}]}}" \
        --dry-run=server &>/dev/null; then
        echo -e "${RED}❌ FAIL: Fifth pod allowed (should exceed quota)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    else
        echo -e "${GREEN}✅ PASS: Fifth pod correctly blocked by quota${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
    
    echo ""
    echo "🧹 Cleaning up test pods..."
    kubectl delete pod quota-test-1 quota-test-2 quota-test-3 quota-test-4 -n app-ml-team &>/dev/null || echo "Some test pods may not exist"
fi

echo ""
echo "📊 Resource Quota Test Results"
echo "==============================="
echo -e "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

# Calculate compliance percentage
if [ $TOTAL_TESTS -gt 0 ]; then
    COMPLIANCE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success rate: ${COMPLIANCE}%"

    if [ $COMPLIANCE -eq 100 ]; then
        echo -e "\n${GREEN}✅ All quota enforcement tests passed!${NC}"
        echo ""
        echo "🎯 Resource Quota Summary:"
        echo "   • Team quotas properly enforced"
        echo "   • Resource isolation working correctly"
        echo "   • LimitRanges preventing excessive individual pods"
        echo "   • Multi-pod quota exhaustion blocked"
        exit 0
    else
        echo -e "\n${RED}❌ Some quota enforcement tests failed${NC}"
        echo ""
        echo "🔧 Check:"
        echo "   • ResourceQuota configurations"
        echo "   • LimitRange settings"
        echo "   • Team namespace configurations"
        exit 1
    fi
else
    echo -e "\n${RED}❌ No tests were executed${NC}"
    exit 1
fi

echo ""
echo "💡 Usage Tips:"
echo "- Run this script regularly to validate quota enforcement"
echo "- Modify CPU/memory values to test different scenarios"
echo "- Check 'kubectl describe quota' for current usage"
echo "- Review 'kubectl describe limitrange' for container constraints"