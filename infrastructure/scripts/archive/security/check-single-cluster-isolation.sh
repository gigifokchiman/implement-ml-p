#!/bin/bash
# Check single cluster team isolation configuration
# This validates that team isolation is properly deployed and configured

set -e

echo "🔍 Checking Single Cluster Team Isolation"
echo "========================================="

# Choose target cluster
CLUSTER_CONTEXT=${1:-kind-data-platform-local}
echo "📋 Target cluster: $CLUSTER_CONTEXT"

# Switch to target cluster
kubectl config use-context $CLUSTER_CONTEXT

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to check resource
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local description=$4
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$namespace" = "cluster-wide" ]; then
        if kubectl get $resource_type $resource_name &>/dev/null; then
            echo -e "${GREEN}✅${NC} $description exists"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}❌${NC} $description missing"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        if kubectl get $resource_type $resource_name -n $namespace &>/dev/null; then
            echo -e "${GREEN}✅${NC} $description exists in $namespace"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}❌${NC} $description missing in $namespace"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
}

# Helper function to check resource quota values
check_quota() {
    local namespace=$1
    local resource=$2
    local expected_value=$3
    local description=$4
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    actual_value=$(kubectl get resourcequota -n $namespace -o jsonpath="{.items[0].spec.hard.$resource}" 2>/dev/null || echo "")
    
    if [ "$actual_value" = "$expected_value" ]; then
        echo -e "${GREEN}✅${NC} $description: $resource=$actual_value"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌${NC} $description: Expected $resource=$expected_value, got '$actual_value'"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Helper function to test RBAC permissions
test_rbac() {
    local user=$1
    local verb=$2
    local resource=$3
    local namespace=$4
    local should_allow=$5
    local description=$6
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if kubectl auth can-i $verb $resource --as=$user -n $namespace &>/dev/null; then
        if [ "$should_allow" = "true" ]; then
            echo -e "${GREEN}✅${NC} $description: ALLOWED (correct)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}❌${NC} $description: ALLOWED (should be denied)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        if [ "$should_allow" = "false" ]; then
            echo -e "${GREEN}✅${NC} $description: DENIED (correct)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}❌${NC} $description: DENIED (should be allowed)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
}

echo ""
echo "1️⃣ Checking Team Namespaces..."
echo "-----------------------------"

# Define expected team namespaces
TEAM_NAMESPACES="app-ml-team app-data-team app-core-team"

for ns in $TEAM_NAMESPACES; do
    echo -e "\n${YELLOW}Checking namespace: $ns${NC}"
    check_resource "namespace" "$ns" "cluster-wide" "Team namespace $ns"
    
    # Check namespace labels
    team_label=$(kubectl get namespace $ns -o jsonpath="{.metadata.labels.team}" 2>/dev/null || echo "")
    if [ ! -z "$team_label" ]; then
        echo -e "${GREEN}✅${NC} Namespace $ns has team label: $team_label"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌${NC} Namespace $ns missing team label"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
done

echo ""
echo "2️⃣ Checking Resource Quotas..."
echo "-----------------------------"

# Check ML team quotas (20 CPU cores, 64GB RAM)
echo -e "\n${YELLOW}ML Team Resource Quotas (app-ml-team):${NC}"
if kubectl get namespace app-ml-team &>/dev/null; then
    check_quota "app-ml-team" "requests.cpu" "20" "ML team CPU quota"
    check_quota "app-ml-team" "requests.memory" "64Gi" "ML team memory quota"
    check_quota "app-ml-team" "requests.storage" "500Gi" "ML team storage quota"
else
    echo -e "${RED}❌${NC} ML team namespace not found - skipping quota checks"
    FAILED_CHECKS=$((FAILED_CHECKS + 3))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 3))
fi

# Check Data team quotas (16 CPU cores, 48GB RAM)
echo -e "\n${YELLOW}Data Team Resource Quotas (app-data-team):${NC}"
if kubectl get namespace app-data-team &>/dev/null; then
    check_quota "app-data-team" "requests.cpu" "16" "Data team CPU quota"
    check_quota "app-data-team" "requests.memory" "48Gi" "Data team memory quota"
    check_quota "app-data-team" "requests.storage" "1Ti" "Data team storage quota"
else
    echo -e "${RED}❌${NC} Data team namespace not found - skipping quota checks"
    FAILED_CHECKS=$((FAILED_CHECKS + 3))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 3))
fi

# Check App team quotas (8 CPU cores, 24GB RAM)
echo -e "\n${YELLOW}App Team Resource Quotas (app-core-team):${NC}"
if kubectl get namespace app-core-team &>/dev/null; then
    check_quota "app-core-team" "requests.cpu" "8" "App team CPU quota"
    check_quota "app-core-team" "requests.memory" "24Gi" "App team memory quota"
    check_quota "app-core-team" "requests.storage" "200Gi" "App team storage quota"
else
    echo -e "${RED}❌${NC} App team namespace not found - skipping quota checks"
    FAILED_CHECKS=$((FAILED_CHECKS + 3))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 3))
fi

echo ""
echo "3️⃣ Checking RBAC Policies..."
echo "---------------------------"

# Check ClusterRoles exist
echo -e "\n${YELLOW}Checking ClusterRoles:${NC}"
check_resource "clusterrole" "ml-team-role" "cluster-wide" "ML team ClusterRole"
check_resource "clusterrole" "data-team-role" "cluster-wide" "Data team ClusterRole"
check_resource "clusterrole" "app-team-role" "cluster-wide" "App team ClusterRole"

# Check RoleBindings exist
echo -e "\n${YELLOW}Checking RoleBindings:${NC}"
if kubectl get namespace app-ml-team &>/dev/null; then
    check_resource "rolebinding" "ml-team-binding" "app-ml-team" "ML team RoleBinding"
fi
if kubectl get namespace app-data-team &>/dev/null; then
    check_resource "rolebinding" "data-team-binding" "app-data-team" "Data team RoleBinding"
fi
if kubectl get namespace app-core-team &>/dev/null; then
    check_resource "rolebinding" "app-team-binding" "app-core-team" "App team RoleBinding"
fi

echo ""
echo "4️⃣ Testing RBAC Isolation..."
echo "---------------------------"

# Test ML team permissions
echo -e "\n${YELLOW}Testing ML Team RBAC:${NC}"
test_rbac "system:serviceaccount:app-ml-team:default" "create" "pods" "app-ml-team" "true" "ML team can create pods in own namespace"
test_rbac "system:serviceaccount:app-ml-team:default" "create" "pods" "app-data-team" "false" "ML team cannot create pods in data namespace"
test_rbac "system:serviceaccount:app-ml-team:default" "create" "pods" "app-core-team" "false" "ML team cannot create pods in app namespace"

# Test Data team permissions
echo -e "\n${YELLOW}Testing Data Team RBAC:${NC}"
test_rbac "system:serviceaccount:app-data-team:default" "create" "pods" "app-data-team" "true" "Data team can create pods in own namespace"
test_rbac "system:serviceaccount:app-data-team:default" "create" "pods" "app-ml-team" "false" "Data team cannot create pods in ML namespace"
test_rbac "system:serviceaccount:app-data-team:default" "create" "pods" "app-core-team" "false" "Data team cannot create pods in app namespace"

# Test App team permissions
echo -e "\n${YELLOW}Testing App Team RBAC:${NC}"
test_rbac "system:serviceaccount:app-core-team:default" "create" "pods" "app-core-team" "true" "App team can create pods in own namespace"
test_rbac "system:serviceaccount:app-core-team:default" "create" "pods" "app-ml-team" "false" "App team cannot create pods in ML namespace"
test_rbac "system:serviceaccount:app-core-team:default" "create" "pods" "app-data-team" "false" "App team cannot create pods in data namespace"

echo ""
echo "5️⃣ Checking Network Policies..."
echo "------------------------------"

# Check if network policies exist
for ns in $TEAM_NAMESPACES; do
    if kubectl get namespace $ns &>/dev/null; then
        echo -e "\n${YELLOW}Checking $ns network policies:${NC}"
        policy_name="${ns}-policy"
        check_resource "networkpolicy" "$policy_name" "$ns" "Network policy for $ns"
    fi
done

echo ""
echo "6️⃣ Checking Monitoring Setup..."
echo "------------------------------"

# Check if ServiceMonitors exist (if Prometheus is installed)
if kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    echo -e "\n${YELLOW}Checking ServiceMonitors:${NC}"
    for ns in $TEAM_NAMESPACES; do
        if kubectl get namespace $ns &>/dev/null; then
            sm_count=$(kubectl get servicemonitor -n $ns --no-headers 2>/dev/null | wc -l)
            if [ "$sm_count" -gt 0 ]; then
                echo -e "${GREEN}✅${NC} Found $sm_count ServiceMonitor(s) in $ns"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                echo -e "${YELLOW}⚠️${NC} No ServiceMonitors found in $ns (may be expected)"
            fi
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        fi
    done
else
    echo -e "${YELLOW}ℹ️${NC}  Prometheus CRDs not installed - skipping ServiceMonitor checks"
fi

echo ""
echo "📊 Team Isolation Compliance Report"
echo "==================================="
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"

# Calculate compliance percentage
if [ $TOTAL_CHECKS -gt 0 ]; then
    COMPLIANCE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo -e "Compliance: ${COMPLIANCE}%"

    if [ $COMPLIANCE -eq 100 ]; then
        echo -e "\n${GREEN}✅ Full team isolation compliance achieved!${NC}"
        echo ""
        echo "🎯 Team Isolation Summary:"
        echo "   • All team namespaces properly configured"
        echo "   • Resource quotas enforced"
        echo "   • RBAC isolation working"
        echo "   • Network policies in place"
        exit 0
    elif [ $COMPLIANCE -ge 80 ]; then
        echo -e "\n${YELLOW}⚠️  Good isolation, but some configurations missing${NC}"
        echo ""
        echo "💡 Next Steps:"
        echo "   • Deploy missing team resources: ./infrastructure/scripts/security/deploy-single-cluster-isolation.sh"
        echo "   • Check RBAC configurations"
        echo "   • Verify network policies"
        exit 0
    else
        echo -e "\n${RED}❌ Low compliance - team isolation not properly configured${NC}"
        echo ""
        echo "🔧 Required Actions:"
        echo "   1. Deploy team isolation: ./infrastructure/scripts/security/deploy-single-cluster-isolation.sh"
        echo "   2. Check cluster RBAC configuration"
        echo "   3. Verify namespace creation and labeling"
        echo "   4. Review resource quota settings"
        exit 1
    fi
else
    echo -e "\n${RED}❌ No team isolation resources found${NC}"
    echo "Please run: ./infrastructure/scripts/security/deploy-single-cluster-isolation.sh"
    exit 1
fi

echo ""
echo "💡 Tips:"
echo "- Run the deployment script if resources are missing"
echo "- Use 'kubectl describe quota' to see resource usage"
echo "- Test RBAC with 'kubectl auth can-i' commands"
echo "- Check network connectivity between namespaces"