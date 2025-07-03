#!/bin/bash
set -euo pipefail

# Simple Deployment Script for ML Platform
# Deploys applications using Kustomize without ArgoCD complexity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$INFRA_DIR/kubernetes"

# Default configuration
ENVIRONMENT="local"
COMPONENT="all"
DRY_RUN=false
WAIT_TIMEOUT=300
SKIP_TERRAFORM=false

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

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Simple deployment script for ML Platform using Kustomize

OPTIONS:
    -e, --environment ENV    Target environment (local, dev, staging, prod)
    -c, --component COMP     Component to deploy (all, terraform, kubernetes)
    -d, --dry-run           Show what would be deployed without applying
    --skip-terraform        Skip Terraform deployment
    --wait-timeout SECONDS  Timeout for waiting on deployments (default: 300)
    -h, --help              Show this help message

ENVIRONMENTS:
    local      Local Kind cluster
    dev        AWS EKS development cluster
    staging    AWS EKS staging cluster
    prod       AWS EKS production cluster

EXAMPLES:
    $0 -e local              # Deploy everything to local
    $0 -e dev -c kubernetes  # Deploy only K8s to dev
    $0 -e prod -d           # Dry run for production
    $0 --skip-terraform     # Deploy only applications

PREREQUISITES:
    - kubectl configured for target cluster
    - Terraform (if deploying infrastructure)
    - Kustomize (installed automatically)
EOF
}

check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check if we can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log "ERROR" "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    # Check Terraform if needed
    if [[ "$COMPONENT" == "all" || "$COMPONENT" == "terraform" ]] && [[ "$SKIP_TERRAFORM" == "false" ]]; then
        if ! command -v terraform &> /dev/null; then
            log "ERROR" "Terraform not found. Please install Terraform or use --skip-terraform."
            exit 1
        fi
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

install_kustomize() {
    if ! command -v kustomize &> /dev/null; then
        log "INFO" "Installing Kustomize..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        log "SUCCESS" "Kustomize installed successfully"
    else
        log "INFO" "Kustomize is already installed"
    fi
}

deploy_terraform() {
    if [[ "$SKIP_TERRAFORM" == "true" ]]; then
        log "INFO" "Skipping Terraform deployment"
        return 0
    fi
    
    log "INFO" "Deploying Terraform infrastructure for $ENVIRONMENT"
    
    local terraform_dir="$INFRA_DIR/terraform/environments/$ENVIRONMENT"
    
    if [[ ! -d "$terraform_dir" ]]; then
        log "ERROR" "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Terraform dry run (plan only)"
        terraform init -upgrade
        terraform plan
    else
        log "INFO" "Applying Terraform configuration..."
        terraform init -upgrade
        terraform apply -auto-approve
    fi
    
    log "SUCCESS" "Terraform deployment completed"
}

deploy_kubernetes() {
    log "INFO" "Deploying Kubernetes applications for $ENVIRONMENT"
    
    local overlay_dir="$K8S_DIR/overlays/$ENVIRONMENT"
    
    if [[ ! -d "$overlay_dir" ]]; then
        log "ERROR" "Kubernetes overlay not found: $overlay_dir"
        exit 1
    fi
    
    install_kustomize
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Kubernetes dry run (showing manifests)"
        kustomize build "$overlay_dir"
        return 0
    fi
    
    log "INFO" "Applying Kubernetes manifests..."
    kustomize build "$overlay_dir" | kubectl apply -f -
    
    # Wait for deployments to be ready
    log "INFO" "Waiting for deployments to be ready..."
    
    local namespace="ml-platform"
    local deployments=("backend" "frontend")
    
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$namespace" &> /dev/null; then
            log "INFO" "Waiting for $deployment deployment..."
            kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="${WAIT_TIMEOUT}s" || {
                log "WARN" "Timeout waiting for $deployment to be ready"
            }
        else
            log "WARN" "Deployment $deployment not found in namespace $namespace"
        fi
    done
    
    log "SUCCESS" "Kubernetes deployment completed"
}

show_deployment_status() {
    log "INFO" "Checking deployment status..."
    
    local namespace="ml-platform"
    
    echo ""
    echo "=========================================="
    echo "Deployment Status - $ENVIRONMENT"
    echo "=========================================="
    
    echo ""
    echo "Pods:"
    kubectl get pods -n "$namespace" -o wide 2>/dev/null || echo "No pods found in namespace $namespace"
    
    echo ""
    echo "Services:"
    kubectl get services -n "$namespace" 2>/dev/null || echo "No services found in namespace $namespace"
    
    echo ""
    echo "Ingress:"
    kubectl get ingress -n "$namespace" 2>/dev/null || echo "No ingress found in namespace $namespace"
    
    # Show access information based on environment
    echo ""
    echo "Access Information:"
    case "$ENVIRONMENT" in
        "local")
            echo "- Frontend: http://localhost:8080 (if ingress is configured)"
            echo "- Port forward: kubectl port-forward -n $namespace svc/frontend 8080:3000"
            ;;
        "dev"|"staging"|"prod")
            local ingress_host
            ingress_host=$(kubectl get ingress -n "$namespace" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "Not configured")
            echo "- Web UI: https://$ingress_host"
            echo "- Port forward: kubectl port-forward -n $namespace svc/frontend 8080:3000"
            ;;
    esac
    
    echo ""
}

validate_environment() {
    case "$ENVIRONMENT" in
        "local"|"dev"|"staging"|"prod") ;;
        *)
            log "ERROR" "Invalid environment: $ENVIRONMENT"
            log "INFO" "Valid environments: local, dev, staging, prod"
            exit 1
            ;;
    esac
}

validate_component() {
    case "$COMPONENT" in
        "all"|"terraform"|"kubernetes") ;;
        *)
            log "ERROR" "Invalid component: $COMPONENT"
            log "INFO" "Valid components: all, terraform, kubernetes"
            exit 1
            ;;
    esac
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
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        --wait-timeout)
            WAIT_TIMEOUT="$2"
            shift 2
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

# Main execution
main() {
    log "INFO" "Starting ML Platform deployment"
    log "INFO" "Environment: $ENVIRONMENT"
    log "INFO" "Component: $COMPONENT"
    log "INFO" "Dry run: $DRY_RUN"
    
    validate_environment
    validate_component
    check_prerequisites
    
    local start_time=$(date +%s)
    
    # Deploy components based on selection
    case "$COMPONENT" in
        "all")
            deploy_terraform
            deploy_kubernetes
            ;;
        "terraform")
            deploy_terraform
            ;;
        "kubernetes")
            deploy_kubernetes
            ;;
    esac
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ "$DRY_RUN" == "false" ]]; then
        show_deployment_status
    fi
    
    log "SUCCESS" "Deployment completed successfully in ${duration}s"
    
    # Show next steps
    if [[ "$DRY_RUN" == "false" ]] && [[ "$COMPONENT" != "terraform" ]]; then
        echo ""
        echo "🎉 Next Steps:"
        echo "1. Verify application is running: kubectl get pods -n ml-platform"
        echo "2. Check application logs: kubectl logs -f -l app=backend -n ml-platform"
        echo "3. Access the application using the URLs shown above"
        
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            echo ""
            echo "⚠️  Production Deployment Notes:"
            echo "- Monitor application health and performance"
            echo "- Set up alerts and monitoring"
            echo "- Verify all production checks are working"
        fi
    fi
}

main "$@"