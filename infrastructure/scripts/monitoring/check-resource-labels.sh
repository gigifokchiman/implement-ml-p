#!/bin/bash
# Check that resources have proper labels applied (compliance/audit tool)
# This validates that Terraform/K8s manifests have applied expected labels

set -e

echo "🔍 Checking Resource Label Compliance"
echo "===================================="

CLUSTER_CONTEXT=${1:-kind-data-platform-local}
kubectl config use-context $CLUSTER_CONTEXT

# Determine environment from cluster context
if [[ "$CLUSTER_CONTEXT" == *"local"* ]]; then
    EXPECTED_ENVIRONMENT="local"
elif [[ "$CLUSTER_CONTEXT" == *"dev"* ]]; then
    EXPECTED_ENVIRONMENT="dev"
elif [[ "$CLUSTER_CONTEXT" == *"staging"* ]]; then
    EXPECTED_ENVIRONMENT="staging"
elif [[ "$CLUSTER_CONTEXT" == *"prod"* ]]; then
    EXPECTED_ENVIRONMENT="production"
else
    EXPECTED_ENVIRONMENT="local"  # Default fallback
fi

echo "Environment detected from context: $EXPECTED_ENVIRONMENT"

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function to check label
check_label() {
    local resource_type=$1
    local resource_name=$2
    local label_key=$3
    local expected_value=$4
    local description=$5
    local namespace_param=${6:-""}

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Get actual label value (escape dots and slashes for jsonpath)
    escaped_key=$(echo "$label_key" | sed 's/\./\\./g' | sed 's/\//\\\//g')
    actual_value=$(kubectl get $resource_type $resource_name $namespace_param -o jsonpath="{.metadata.labels.$escaped_key}" 2>/dev/null || echo "")

    if [ "$actual_value" = "$expected_value" ] || [ "$expected_value" = "*" -a ! -z "$actual_value" ]; then
        echo -e "${GREEN}✅${NC} $description: $label_key=$actual_value"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌${NC} $description: Expected $label_key=$expected_value, got '$actual_value'"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Helper function to check service selector
check_selector() {
    local service_name=$1
    local selector_key=$2
    local expected_value=$3
    local description=$4
    local namespace_param=${5:-""}

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Get actual selector value (escape dots and slashes for jsonpath)
    escaped_key=$(echo "$selector_key" | sed 's/\./\\./g' | sed 's/\//\\\//g')
    actual_value=$(kubectl get svc $service_name $namespace_param -o jsonpath="{.spec.selector.$escaped_key}" 2>/dev/null || echo "")

    if [ "$actual_value" = "$expected_value" ] || [ "$expected_value" = "*" -a ! -z "$actual_value" ]; then
        echo -e "${GREEN}✅${NC} $description: $selector_key=$actual_value"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌${NC} $description: Expected $selector_key=$expected_value, got '$actual_value'"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

echo ""
echo "1️⃣ Checking Node Labels..."
echo "------------------------"

# Check if nodes have required labels (set by Terraform/cloud provider)
for node in $(kubectl get nodes -o name); do
    node_name=$(echo $node | cut -d'/' -f2)
    echo -e "\n${YELLOW}Node: $node_name${NC}"

    # Check for required node labels
    check_label "node" "$node_name" "environment" "$EXPECTED_ENVIRONMENT" "Environment label"
    check_label "node" "$node_name" "cluster-name" "data-platform-local" "Cluster name label"

    # Check workload-type exists (value can vary)
    workload_type=$(kubectl get node $node_name -o jsonpath="{.metadata.labels.workload-type}" 2>/dev/null || echo "")
    if [ ! -z "$workload_type" ]; then
        echo -e "${GREEN}✅${NC} Workload type label: workload-type=$workload_type"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌${NC} Missing workload-type label"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
done

echo ""
echo "2️⃣ Checking Namespace Labels..."
echo "-----------------------------"

# Define known namespaces by category
TEAM_NAMESPACES="app-ml-team app-data-team app-core-team"
PLATFORM_NAMESPACES="monitoring database cache storage argocd performance-monitoring security-scanning secret-store audit-logging"
SYSTEM_NAMESPACES="kube-system kube-public kube-node-lease local-path-storage default cert-manager ingress-nginx"

# Combine all known namespaces
KNOWN_NAMESPACES="$TEAM_NAMESPACES $PLATFORM_NAMESPACES"
CHECKED_NAMESPACES=""
UNKNOWN_NAMESPACES=""

# Function to check if namespace is known
is_known_namespace() {
    local ns=$1
    for known in $KNOWN_NAMESPACES; do
        if [ "$ns" = "$known" ]; then
            return 0
        fi
    done
    return 1
}

# Function to check if namespace is system namespace
is_system_namespace() {
    local ns=$1
    for system in $SYSTEM_NAMESPACES; do
        if [ "$ns" = "$system" ]; then
            return 0
        fi
    done
    return 1
}

# Function to get namespace category
get_namespace_category() {
    local ns=$1
    for team_ns in $TEAM_NAMESPACES; do
        if [ "$ns" = "$team_ns" ]; then
            echo "team"
            return 0
        fi
    done
    for platform_ns in $PLATFORM_NAMESPACES; do
        if [ "$ns" = "$platform_ns" ]; then
            echo "platform"
            return 0
        fi
    done
    if is_system_namespace "$ns"; then
        echo "system"
        return 0
    fi
    echo "unknown"
}

# Get all namespaces
ALL_NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

# Check known namespaces first
echo "📋 Checking Known Namespaces by Category:"
echo "========================================="

# Check Team Namespaces
echo -e "\n${BLUE}👥 Team Namespaces:${NC}"
for ns in $TEAM_NAMESPACES; do
    if kubectl get namespace $ns &>/dev/null; then
        echo -e "\n${YELLOW}Namespace: $ns (team)${NC}"
        CHECKED_NAMESPACES="$CHECKED_NAMESPACES $ns"

        case $ns in
            app-ml-team)
                check_label "namespace" "$ns" "team" "ml-engineering" "Team label"
                check_label "namespace" "$ns" "cost-center" "ml" "Cost center label"
                ;;
            app-data-team)
                check_label "namespace" "$ns" "team" "data-engineering" "Team label"
                check_label "namespace" "$ns" "cost-center" "data" "Cost center label"
                ;;
            app-core-team)
                check_label "namespace" "$ns" "team" "app-engineering" "Team label"
                check_label "namespace" "$ns" "cost-center" "app" "Cost center label"
                ;;
        esac
        
        check_label "namespace" "$ns" "environment" "$EXPECTED_ENVIRONMENT" "Environment label"
        
        # Check workload-type
        workload_type=$(kubectl get namespace $ns -o jsonpath="{.metadata.labels.workload-type}" 2>/dev/null || echo "")
        if [ ! -z "$workload_type" ]; then
            echo -e "${GREEN}✅${NC} Workload type label: workload-type=$workload_type"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${YELLOW}⚠️${NC} Missing workload-type label (optional)"
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    else
        echo -e "\n${YELLOW}⚠️  Team namespace $ns not found${NC}"
    fi
done

# Check Platform Namespaces
echo -e "\n${BLUE}🏗️  Platform Namespaces:${NC}"
for ns in $PLATFORM_NAMESPACES; do
    if kubectl get namespace $ns &>/dev/null; then
        echo -e "\n${YELLOW}Namespace: $ns (platform)${NC}"
        CHECKED_NAMESPACES="$CHECKED_NAMESPACES $ns"

        # All platform namespaces have same team/cost-center
        check_label "namespace" "$ns" "team" "platform-engineering" "Team label"
        check_label "namespace" "$ns" "cost-center" "platform" "Cost center label"
        check_label "namespace" "$ns" "environment" "$EXPECTED_ENVIRONMENT" "Environment label"
        
        # Check workload-type
        workload_type=$(kubectl get namespace $ns -o jsonpath="{.metadata.labels.workload-type}" 2>/dev/null || echo "")
        if [ ! -z "$workload_type" ]; then
            echo -e "${GREEN}✅${NC} Workload type label: workload-type=$workload_type"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${YELLOW}⚠️${NC} Missing workload-type label (optional)"
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    else
        echo -e "\n${YELLOW}⚠️  Platform namespace $ns not found${NC}"
    fi
done

# Check for unknown/other namespaces
echo ""
echo ""
echo "🔍 Checking Other Namespaces:"
echo "============================="

FOUND_UNKNOWN=false
SYSTEM_COUNT=0
UNKNOWN_COUNT=0

for ns in $ALL_NAMESPACES; do
    if ! is_known_namespace "$ns"; then
        if [ "$FOUND_UNKNOWN" = false ]; then
            FOUND_UNKNOWN=true
        fi
        
        category=$(get_namespace_category "$ns")
        
        if [ "$category" = "system" ]; then
            echo -e "\n${YELLOW}Namespace: $ns (system)${NC}"
            echo -e "${GREEN}✅${NC} System namespace - labeling not required"
            SYSTEM_COUNT=$((SYSTEM_COUNT + 1))
        else
            echo -e "\n${YELLOW}Namespace: $ns (unknown)${NC}"
            UNKNOWN_NAMESPACES="$UNKNOWN_NAMESPACES $ns"
            UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
            
            # Check if it has any of our standard labels
            team_label=$(kubectl get namespace $ns -o jsonpath="{.metadata.labels.team}" 2>/dev/null || echo "")
            env_label=$(kubectl get namespace $ns -o jsonpath="{.metadata.labels.environment}" 2>/dev/null || echo "")
            cost_label=$(kubectl get namespace $ns -o jsonpath="{.metadata.labels.cost-center}" 2>/dev/null || echo "")
            
            if [ ! -z "$team_label" ] || [ ! -z "$env_label" ] || [ ! -z "$cost_label" ]; then
                echo -e "${GREEN}ℹ️${NC}  Has some labels: team=$team_label, environment=$env_label, cost-center=$cost_label"
            else
                echo -e "${YELLOW}⚠️${NC}  No standard labels found"
            fi
            
            echo -e "${RED}❌${NC} Unknown application namespace - should have labels"
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
done

if [ "$FOUND_UNKNOWN" = false ]; then
    echo -e "${GREEN}✅ No unknown namespaces found${NC}"
fi

echo ""
echo "3️⃣ Checking Service Labels and Selectors..."
echo "--------------------------------------------"

# Check key services have proper labels
for svc in postgres redis minio; do
    namespace=$(kubectl get svc --all-namespaces -o json | jq -r ".items[] | select(.metadata.name==\"$svc\") | .metadata.namespace" 2>/dev/null || echo "")

    if [ ! -z "$namespace" ]; then
        echo -e "\n${YELLOW}Service: $svc (namespace: $namespace)${NC}"

        # Check service labels
        check_label "svc" "$svc" "app.kubernetes.io/name" "$svc" "App name label" "-n $namespace"
        check_label "svc" "$svc" "app.kubernetes.io/component" "*" "Component label" "-n $namespace"
        
        # Check service selectors
        check_selector "$svc" "app.kubernetes.io/name" "$svc" "Selector app name" "-n $namespace"
    fi
done

echo ""
echo "📊 Compliance Report"
echo "==================="
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"

# Report on namespace coverage
echo ""
echo "📋 Namespace Coverage:"
echo "====================="
TEAM_COUNT=$(echo $TEAM_NAMESPACES | wc -w | xargs)
PLATFORM_COUNT=$(echo $PLATFORM_NAMESPACES | wc -w | xargs)
KNOWN_COUNT=$(echo $CHECKED_NAMESPACES | wc -w | xargs)

echo -e "Team namespaces: ${BLUE}$TEAM_COUNT${NC}"
echo -e "Platform namespaces: ${BLUE}$PLATFORM_COUNT${NC}"
echo -e "Known namespaces checked: ${GREEN}$KNOWN_COUNT${NC}"
echo -e "System namespaces found: ${GREEN}$SYSTEM_COUNT${NC}"
if [ "$UNKNOWN_COUNT" -gt 0 ]; then
    echo -e "Unknown namespaces found: ${RED}$UNKNOWN_COUNT${NC}"
    echo -e "Unknown namespaces:${UNKNOWN_NAMESPACES}"
else
    echo -e "Unknown namespaces found: ${GREEN}0${NC}"
fi

# Calculate compliance percentage
if [ $TOTAL_CHECKS -gt 0 ]; then
    COMPLIANCE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo -e "Compliance: ${COMPLIANCE}%"

    if [ $COMPLIANCE -eq 100 ]; then
        echo -e "\n${GREEN}✅ Full compliance achieved!${NC}"
        exit 0
    elif [ $COMPLIANCE -ge 80 ]; then
        echo -e "\n${YELLOW}⚠️  Good compliance, but some labels missing${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Low compliance - review Terraform/K8s configurations${NC}"
        exit 1
    fi
else
    echo -e "\n${RED}❌ No resources found to check${NC}"
    exit 1
fi

echo ""
echo "💡 Tips:"
echo "- Labels should be set in Terraform configs or K8s manifests"
echo "- Use 'kubectl label' only for temporary debugging"
echo "- Check terraform/modules/ for node label configurations"
echo "- Check kubernetes/team-isolation/ for namespace labels"
