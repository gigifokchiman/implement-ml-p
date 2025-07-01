#!/bin/bash

# Local ML Platform Deployment Script
# Deploys infrastructure (Terraform) then applications (Kustomize)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform/environments/local"
KUSTOMIZE_DIR="${SCRIPT_DIR}/kubernetes/overlays/local"

# Default values
DESTROY_FIRST=false
SKIP_TERRAFORM=false
SKIP_APPLICATIONS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --destroy-first)
            DESTROY_FIRST=true
            shift
            ;;
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        --skip-applications)
            SKIP_APPLICATIONS=true
            shift
            ;;
        --help|-h)
            echo "Local ML Platform Deployment Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --destroy-first       Destroy existing infrastructure before deploying"
            echo "  --skip-terraform      Skip infrastructure deployment (Terraform)"
            echo "  --skip-applications   Skip application deployment (Kustomize)"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Deploy everything"
            echo "  $0 --destroy-first    # Clean deployment"
            echo "  $0 --skip-terraform   # Only deploy applications"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()

    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v kustomize &> /dev/null; then
        missing_tools+=("kustomize")
    fi

    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying infrastructure (Layer 1: Terraform)..."

    cd "$TERRAFORM_DIR"

    if [ "$DESTROY_FIRST" = true ]; then
        log_warn "Destroying existing infrastructure..."
        terraform destroy -auto-approve || log_warn "Destroy failed or nothing to destroy"
    fi

    log_info "Initializing Terraform..."
    terraform init

    log_info "Planning infrastructure deployment..."
    terraform plan -out=tfplan

    log_info "Applying infrastructure changes..."
    terraform apply tfplan

    # Wait for cluster to be ready
    log_info "Waiting for Kind cluster to be ready..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if kubectl cluster-info &> /dev/null; then
            log_success "Cluster is ready"
            break
        fi
        log_info "Waiting for cluster... ($retries retries left)"
        sleep 10
        ((retries--))
    done

    if [ $retries -eq 0 ]; then
        log_error "Cluster failed to become ready"
        exit 1
    fi

    # Wait for ML platform services to be ready
    log_info "Waiting for ML platform services to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n ml-platform --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n ml-platform --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=minio -n ml-platform --timeout=300s || true

    log_success "Infrastructure deployment completed"
}

# Deploy applications with Kustomize
deploy_applications() {
    log_info "Deploying applications (Layer 2: Kustomize)..."

    cd "$KUSTOMIZE_DIR"

    # Build and validate Kustomize configuration
    log_info "Building Kustomize configuration..."
    if ! kustomize build . > /tmp/ml-platform-local.yaml; then
        log_error "Failed to build Kustomize configuration"
        exit 1
    fi

    # Dry run first
    log_info "Running dry-run validation..."
    if ! kubectl apply --dry-run=server -f /tmp/ml-platform-local.yaml; then
        log_error "Dry-run validation failed"
        exit 1
    fi

    # Apply the configuration
    log_info "Applying application configuration..."
    kubectl apply -f /tmp/ml-platform-local.yaml

    # Wait for applications to be ready
    log_info "Waiting for applications to be ready..."
    kubectl wait --for=condition=available deployment -l app.kubernetes.io/part-of=ml-platform -n ml-platform --timeout=300s || true

    log_success "Application deployment completed"
}

# Show deployment status
show_status() {
    log_info "Deployment Status Summary"
    echo "=================================="

    # Infrastructure status
    echo "Infrastructure (Terraform):"
    cd "$TERRAFORM_DIR"
    if terraform output cluster_info &> /dev/null; then
        echo "  ✅ Kind cluster: Running"
    else
        echo "  ❌ Kind cluster: Not found"
    fi

    if terraform output development_urls &> /dev/null; then
        echo "  ✅ ML Platform services: Deployed"
    else
        echo "  ❌ ML Platform services: Not found"
    fi

    # Application status
    echo ""
    echo "Applications (Kustomize):"
    if kubectl get namespace ml-platform &> /dev/null; then
        local ready_pods=$(kubectl get pods -n ml-platform --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_pods=$(kubectl get pods -n ml-platform --no-headers 2>/dev/null | wc -l)
        echo "  📊 Pods: $ready_pods/$total_pods ready"

        if kubectl get deployment ml-platform-backend -n ml-platform &> /dev/null; then
            echo "  ✅ Backend: Deployed"
        else
            echo "  ❌ Backend: Not found"
        fi
    else
        echo "  ❌ ML Platform namespace: Not found"
    fi

    echo ""
    echo "Access URLs:"
    echo "  🌐 Ingress: http://localhost:8080"
    echo "  📊 MinIO Console: http://localhost:9001"
    echo "  🔍 Registry: http://localhost:5001"

    echo ""
    echo "Useful Commands:"
    echo "  kubectl get pods -n ml-platform"
    echo "  kubectl logs -l app.kubernetes.io/name=ml-platform-backend -n ml-platform"
    echo "  terraform output -state=$TERRAFORM_DIR/terraform.tfstate"
}

# Main execution

main() {
    log_info "Starting ML Platform local deployment..."
    log_info "Terraform dir: $TERRAFORM_DIR"
    log_info "Kustomize dir: $KUSTOMIZE_DIR"

    check_prerequisites

    if [ "$SKIP_TERRAFORM" = false ]; then
        deploy_infrastructure
    else
        log_warn "Skipping infrastructure deployment (Terraform)"
    fi

    if [ "$SKIP_APPLICATIONS" = false ]; then
        deploy_applications
    else
        log_warn "Skipping application deployment (Kustomize)"
    fi

    show_status

    log_success "ML Platform local deployment completed!"
    log_info "Run './tests/run-all.sh' to validate the deployment"
}

# Execute main function
main "$@"
