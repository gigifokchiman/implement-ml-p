#!/bin/bash
set -euo pipefail

# Unified deployment script for ML Platform
# Supports multiple environments and deployment methods

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="local"
COMPONENT="all"
DRY_RUN=false
SKIP_TERRAFORM=false
SKIP_KUBERNETES=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy ML Platform infrastructure and applications

OPTIONS:
    -e, --environment ENV    Target environment (local, dev, staging, prod) [default: local]
    -c, --component COMP     Component to deploy (terraform, kubernetes, all) [default: all]
    -d, --dry-run           Show what would be deployed without making changes
    -t, --skip-terraform    Skip Terraform deployment
    -k, --skip-kubernetes   Skip Kubernetes deployment
    -h, --help              Show this help message

EXAMPLES:
    $0 -e local                    # Deploy everything to local environment
    $0 -e prod -c terraform        # Deploy only Terraform infrastructure to prod
    $0 -e staging -d               # Dry run for staging environment
    $0 -e dev --skip-terraform     # Deploy only Kubernetes to dev (assuming infra exists)

ENVIRONMENTS:
    local     - Kind cluster for local development
    dev       - AWS EKS development environment
    staging   - AWS EKS staging environment
    prod      - AWS EKS production environment
EOF
}

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

check_dependencies() {
    local deps=("kubectl" "kustomize")
    
    if [[ "$ENVIRONMENT" != "local" ]]; then
        deps+=("terraform" "aws")
    fi
    
    if [[ "$ENVIRONMENT" == "local" ]]; then
        deps+=("kind" "docker")
    fi
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required dependency '$cmd' not found"
            exit 1
        fi
    done
    
    log "INFO" "All dependencies satisfied"
}

deploy_terraform() {
    local env_dir="$INFRA_DIR/terraform/environments/$ENVIRONMENT"
    
    if [[ ! -d "$env_dir" ]]; then
        log "ERROR" "Terraform environment directory not found: $env_dir"
        exit 1
    fi
    
    log "INFO" "Deploying Terraform infrastructure for environment: $ENVIRONMENT"
    
    cd "$env_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Terraform plan (dry run):"
        terraform plan
    else
        terraform init
        terraform apply -auto-approve
        log "SUCCESS" "Terraform infrastructure deployed"
    fi
}

setup_kind_cluster() {
    local cluster_name="ml-platform-local"
    
    if kind get clusters | grep -q "$cluster_name"; then
        log "INFO" "Kind cluster '$cluster_name' already exists"
    else
        log "INFO" "Creating Kind cluster: $cluster_name"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "Would create Kind cluster: $cluster_name"
        else
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
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
- role: worker
- role: worker
EOF
            log "SUCCESS" "Kind cluster created"
        fi
    fi
    
    # Set kubectl context
    kubectl config use-context "kind-$cluster_name"
}

install_ingress_controller() {
    if [[ "$ENVIRONMENT" == "local" ]]; then
        log "INFO" "Installing NGINX Ingress Controller for Kind"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "Would install NGINX Ingress Controller"
        else
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
            kubectl wait --namespace ingress-nginx \
                --for=condition=ready pod \
                --selector=app.kubernetes.io/component=controller \
                --timeout=90s
            log "SUCCESS" "NGINX Ingress Controller installed"
        fi
    fi
}

deploy_kubernetes() {
    local overlay_dir="$INFRA_DIR/kubernetes/overlays/$ENVIRONMENT"
    
    if [[ ! -d "$overlay_dir" ]]; then
        log "ERROR" "Kubernetes overlay directory not found: $overlay_dir"
        exit 1
    fi
    
    log "INFO" "Deploying Kubernetes applications for environment: $ENVIRONMENT"
    
    cd "$overlay_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Kubernetes manifests (dry run):"
        kustomize build .
    else
        # Apply with server-side dry run first to validate
        kustomize build . | kubectl apply --dry-run=server -f -
        
        # Apply for real
        kustomize build . | kubectl apply -f -
        
        log "SUCCESS" "Kubernetes applications deployed"
        
        # Wait for deployments to be ready
        log "INFO" "Waiting for deployments to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment --all -n ml-platform
        
        log "SUCCESS" "All deployments are ready"
    fi
}

show_access_info() {
    if [[ "$ENVIRONMENT" == "local" && "$DRY_RUN" == "false" ]]; then
        log "INFO" "Local deployment complete!"
        echo ""
        echo "Access URLs:"
        echo "  Frontend:     http://ml-platform.local:30080"
        echo "  API:          http://api.ml-platform.local:30080"
        echo "  MinIO:        http://minio.ml-platform.local:30080"
        echo ""
        echo "Add to /etc/hosts:"
        echo "127.0.0.1 ml-platform.local api.ml-platform.local minio.ml-platform.local"
    elif [[ "$ENVIRONMENT" != "local" && "$DRY_RUN" == "false" ]]; then
        local cluster_name
        cluster_name=$(terraform -chdir="$INFRA_DIR/terraform/environments/$ENVIRONMENT" output -raw cluster_name 2>/dev/null || echo "ml-platform-$ENVIRONMENT")
        
        log "INFO" "AWS deployment complete!"
        echo ""
        echo "To access the cluster:"
        echo "  aws eks update-kubeconfig --region us-west-2 --name $cluster_name"
        echo ""
        echo "Load balancer endpoint:"
        kubectl get ingress -n ml-platform -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending..."
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--component)
            COMPONENT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -t|--skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        -k|--skip-kubernetes)
            SKIP_KUBERNETES=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
case "$ENVIRONMENT" in
    "local"|"dev"|"staging"|"prod") ;;
    *)
        log "ERROR" "Invalid environment: $ENVIRONMENT"
        log "ERROR" "Valid environments: local, dev, staging, prod"
        exit 1
        ;;
esac

# Validate component
case "$COMPONENT" in
    "terraform"|"kubernetes"|"all") ;;
    *)
        log "ERROR" "Invalid component: $COMPONENT"
        log "ERROR" "Valid components: terraform, kubernetes, all"
        exit 1
        ;;
esac

# Main deployment logic
log "INFO" "Starting ML Platform deployment"
log "INFO" "Environment: $ENVIRONMENT"
log "INFO" "Component: $COMPONENT"
log "INFO" "Dry run: $DRY_RUN"

check_dependencies

# Deploy Terraform infrastructure
if [[ "$COMPONENT" == "terraform" || "$COMPONENT" == "all" ]] && [[ "$SKIP_TERRAFORM" == "false" ]]; then
    if [[ "$ENVIRONMENT" == "local" ]]; then
        setup_kind_cluster
        install_ingress_controller
    else
        deploy_terraform
    fi
fi

# Deploy Kubernetes applications
if [[ "$COMPONENT" == "kubernetes" || "$COMPONENT" == "all" ]] && [[ "$SKIP_KUBERNETES" == "false" ]]; then
    deploy_kubernetes
fi

show_access_info

log "SUCCESS" "Deployment completed successfully!"