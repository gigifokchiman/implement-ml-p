#!/bin/bash
# Infrastructure Status Dashboard
# Shows complete view of Terraform infrastructure and Kubernetes applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Environment and options
ENVIRONMENT=${1:-local}
DETAILED=${2:-false}

# Helper functions
print_header() {
    echo -e "\n${WHITE}=================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${WHITE}=================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
}

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

print_help() {
    echo "Usage: $0 [environment] [detailed]"
    echo ""
    echo "Parameters:"
    echo "  environment  - Environment to check (local, dev, staging, prod) [default: local]"
    echo "  detailed     - Show detailed resource information (true/false) [default: false]"
    echo ""
    echo "Examples:"
    echo "  $0 local              # Show local environment summary"
    echo "  $0 local true         # Show local environment with details"
    echo "  $0 dev                # Show dev environment"
    echo ""
}

# Check if help requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print_help
    exit 0
fi

print_header "ML PLATFORM INFRASTRUCTURE STATUS - $(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"

# 1. TERRAFORM INFRASTRUCTURE
print_section "1. TERRAFORM INFRASTRUCTURE"

cd "$(dirname "$0")/../terraform/environments/${ENVIRONMENT}"

if [ -f "terraform.tfstate" ]; then
    echo -e "${GREEN}✓ Terraform state exists${NC}"
    
    # Check if cluster exists
    if terraform output cluster_info &>/dev/null; then
        echo -e "${GREEN}✓ Kind cluster provisioned${NC}"
        
        # Get cluster info
        CLUSTER_NAME=$(terraform output -json cluster_info 2>/dev/null | jq -r '.name // "unknown"')
        echo -e "  Cluster Name: ${CLUSTER_NAME}"
        
        # Check if cluster is actually running
        if kind get clusters | grep -q "${CLUSTER_NAME}"; then
            echo -e "${GREEN}✓ Cluster is running${NC}"
        else
            echo -e "${RED}✗ Cluster not found in kind${NC}"
        fi
    else
        echo -e "${RED}✗ No cluster found in Terraform state${NC}"
    fi
    
    # Show service connections
    if terraform output service_connections &>/dev/null; then
        print_section "Infrastructure Services"
        echo "Database:  $(terraform output -json service_connections 2>/dev/null | jq -r '.database.endpoint // "Not available"')"
        echo "Cache:     $(terraform output -json service_connections 2>/dev/null | jq -r '.cache.endpoint // "Not available"')"
        echo "Storage:   $(terraform output -json service_connections 2>/dev/null | jq -r '.storage.endpoint // "Not available"')"
        echo "Monitor:   $(terraform output -json service_connections 2>/dev/null | jq -r '.monitoring.endpoint // "Not available"')"
    fi
    
    # Show development URLs
    if terraform output development_urls &>/dev/null; then
        print_section "Development URLs"
        terraform output -json development_urls 2>/dev/null | jq -r 'to_entries[] | "\(.key | ascii_upcase): \(.value)"'
    fi
    
else
    echo -e "${RED}✗ No Terraform state found${NC}"
    echo "  Run: terraform init && terraform apply"
fi

# 2. KUBERNETES CLUSTER STATUS
print_section "2. KUBERNETES CLUSTER STATUS"

# Check kubectl context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
EXPECTED_CONTEXT="kind-ml-platform-${ENVIRONMENT}"

if [[ "$CURRENT_CONTEXT" == "$EXPECTED_CONTEXT" ]]; then
    echo -e "${GREEN}✓ Connected to correct cluster: ${CURRENT_CONTEXT}${NC}"
else
    echo -e "${YELLOW}⚠ Current context: ${CURRENT_CONTEXT}${NC}"
    echo -e "  Expected: ${EXPECTED_CONTEXT}"
    echo -e "  Run: kubectl config use-context ${EXPECTED_CONTEXT}"
fi

# Check cluster connectivity
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Cluster is accessible${NC}"
    
    # Show nodes
    echo -e "\nNodes:"
    kubectl get nodes --no-headers 2>/dev/null | while read node status role age version; do
        if [[ "$status" == "Ready" ]]; then
            echo -e "  ${GREEN}✓${NC} $node ($role) - $status"
        else
            echo -e "  ${RED}✗${NC} $node ($role) - $status"
        fi
    done
    
else
    echo -e "${RED}✗ Cannot connect to cluster${NC}"
    echo "  Check if cluster is running: kind get clusters"
fi

# 3. NAMESPACES AND INFRASTRUCTURE SERVICES
print_section "3. INFRASTRUCTURE NAMESPACES"

INFRA_NAMESPACES=("database" "cache" "storage" "monitoring" "argocd")

for ns in "${INFRA_NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $ns"
        
        if [[ "$DETAILED" == "true" ]]; then
            echo "    Pods:"
            kubectl get pods -n "$ns" --no-headers 2>/dev/null | while read pod ready status restarts age; do
                if [[ "$status" == "Running" ]]; then
                    echo -e "      ${GREEN}✓${NC} $pod ($ready ready)"
                elif [[ "$status" == "Pending" ]]; then
                    echo -e "      ${YELLOW}⏳${NC} $pod ($status)"
                else
                    echo -e "      ${RED}✗${NC} $pod ($status)"
                fi
            done
        fi
    else
        echo -e "${RED}✗${NC} $ns (missing)"
    fi
done

# 4. ARGOCD STATUS
print_section "4. ARGOCD GITOPS STATUS"

if kubectl get namespace argocd &>/dev/null; then
    echo -e "${GREEN}✓ ArgoCD namespace exists${NC}"
    
    # Check ArgoCD components
    ARGOCD_COMPONENTS=("argocd-server" "argocd-repo-server" "argocd-application-controller")
    
    for component in "${ARGOCD_COMPONENTS[@]}"; do
        if kubectl get deployment "$component" -n argocd &>/dev/null; then
            READY=$(kubectl get deployment "$component" -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            DESIRED=$(kubectl get deployment "$component" -n argocd -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            
            if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
                echo -e "  ${GREEN}✓${NC} $component ($READY/$DESIRED ready)"
            else
                echo -e "  ${RED}✗${NC} $component ($READY/$DESIRED ready)"
            fi
        else
            echo -e "  ${RED}✗${NC} $component (not found)"
        fi
    done
    
    # Check ArgoCD applications
    print_section "ArgoCD Applications"
    if kubectl get applications -n argocd &>/dev/null; then
        kubectl get applications -n argocd --no-headers 2>/dev/null | while read app sync health status age; do
            if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
                echo -e "  ${GREEN}✓${NC} $app (Synced/Healthy)"
            elif [[ "$sync" == "OutOfSync" ]]; then
                echo -e "  ${YELLOW}⏳${NC} $app (OutOfSync/$health)"
            else
                echo -e "  ${RED}✗${NC} $app ($sync/$health)"
            fi
        done
    else
        echo -e "  ${YELLOW}⚠${NC} No applications found"
    fi
    
    # ArgoCD access info
    print_section "ArgoCD Access"
    echo "Port forward: kubectl port-forward -n argocd svc/argocd-server 8080:80"
    echo "URL: http://localhost:8080"
    echo "Username: admin"
    echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    
else
    echo -e "${RED}✗ ArgoCD not installed${NC}"
    echo "  Install with: ./infrastructure/scripts/bootstrap-argocd.sh ${ENVIRONMENT}"
fi

# 5. APPLICATION DEPLOYMENTS
print_section "5. APPLICATION DEPLOYMENTS"

APP_NAMESPACES=("ml-platform" "data-platform")

for ns in "${APP_NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $ns namespace"
        
        # Show deployments
        if kubectl get deployments -n "$ns" &>/dev/null; then
            kubectl get deployments -n "$ns" --no-headers 2>/dev/null | while read deploy ready uptodate available age; do
                if [[ "$ready" == "$uptodate" && "$ready" == "$available" && "$ready" != "0" ]]; then
                    echo -e "    ${GREEN}✓${NC} $deploy ($ready ready)"
                else
                    echo -e "    ${RED}✗${NC} $deploy ($ready/$uptodate/$available)"
                fi
            done
        fi
        
        # Show services
        if [[ "$DETAILED" == "true" ]]; then
            echo "    Services:"
            kubectl get services -n "$ns" --no-headers 2>/dev/null | while read svc type cluster_ip external_ip ports age; do
                echo -e "      • $svc ($type) - $cluster_ip:$ports"
            done
        fi
        
    else
        echo -e "${YELLOW}⏳${NC} $ns (namespace not created yet)"
        echo "    Will be created when ArgoCD deploys applications"
    fi
done

# 6. STORAGE AND PERSISTENCE
print_section "6. STORAGE & PERSISTENCE"

# Check PVCs
echo "Persistent Volume Claims:"
ALL_PVCs=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null || echo "")

if [[ -n "$ALL_PVCs" ]]; then
    echo "$ALL_PVCs" | while read ns pvc status volume capacity access storage_class age; do
        if [[ "$status" == "Bound" ]]; then
            echo -e "  ${GREEN}✓${NC} $ns/$pvc ($capacity, $storage_class)"
        else
            echo -e "  ${RED}✗${NC} $ns/$pvc ($status)"
        fi
    done
else
    echo -e "  ${YELLOW}⚠${NC} No PVCs found"
fi

# 7. SERVICE CONNECTIONS & RELATIONSHIPS
print_section "7. SERVICE CONNECTIONS"

echo "Infrastructure → Application Connections:"
echo ""
echo "Database (PostgreSQL):"
echo "  - Namespace: database"
echo "  - Service: postgresql.database:5432"
echo "  - Used by: ml-platform, data-platform"
echo ""
echo "Cache (Redis):"
echo "  - Namespace: cache" 
echo "  - Service: redis-master.cache:6379"
echo "  - Used by: ml-platform, data-platform"
echo ""
echo "Storage (MinIO/S3):"
echo "  - Namespace: storage"
echo "  - Service: minio.storage:9000"
echo "  - Buckets: ml-artifacts, data-lake, model-registry, raw-data, processed-data, temp-data"
echo "  - Used by: ml-platform, data-platform"

# 8. USEFUL COMMANDS
print_section "8. USEFUL COMMANDS"

cat << EOF
Port Forwarding:
  kubectl port-forward -n database svc/postgresql 5432:5432
  kubectl port-forward -n cache svc/redis-master 6379:6379
  kubectl port-forward -n storage svc/minio 9001:9000
  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
  kubectl port-forward -n argocd svc/argocd-server 8080:80

Logs:
  kubectl logs -n ml-platform deployment/backend
  kubectl logs -n data-platform deployment/data-api
  kubectl logs -n argocd deployment/argocd-server

Troubleshooting:
  kubectl get events --sort-by=.metadata.creationTimestamp
  kubectl describe pod <pod-name> -n <namespace>
  kubectl get all --all-namespaces

Infrastructure Management:
  terraform plan   # Check infrastructure changes
  terraform apply  # Apply infrastructure changes
  ./scripts/bootstrap-argocd.sh ${ENVIRONMENT}  # Install/update ArgoCD
EOF

# 9. SUMMARY
print_section "9. SUMMARY"

# Count resources
TOTAL_NAMESPACES=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "0")
TOTAL_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
RUNNING_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep Running | wc -l || echo "0")
TOTAL_SERVICES=$(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")

echo "Resource Summary:"
echo "  Namespaces: $TOTAL_NAMESPACES"
echo "  Pods: $RUNNING_PODS/$TOTAL_PODS running"
echo "  Services: $TOTAL_SERVICES"

# Overall status
if [[ "$RUNNING_PODS" -gt 0 ]] && kubectl get namespace argocd &>/dev/null; then
    echo -e "\n${GREEN}✓ Platform Status: Operational${NC}"
else
    echo -e "\n${YELLOW}⚠ Platform Status: Partially Deployed${NC}"
fi

cd - > /dev/null

echo -e "\n${WHITE}Run with 'true' as second parameter for detailed information${NC}"
echo -e "${WHITE}Example: $0 ${ENVIRONMENT} true${NC}"