#!/bin/bash

# ArgoCD Bootstrap Script
# Installs ArgoCD and sets up GitOps for ML Platform

set -euo pipefail

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ARGOCD_VERSION="${ARGOCD_VERSION:-2.9.3}"
ENVIRONMENT="${1:-local}"
REPO_URL="${REPO_URL:-https://github.com/gigifokchiman/implement-ml-p}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-600}"

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

# Print usage
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT]

Bootstrap ArgoCD for ML Platform GitOps

ENVIRONMENT:
    local       Local Kind cluster (default)
    dev         Development environment
    staging     Staging environment  
    prod        Production environment

Environment Variables:
    ARGOCD_VERSION    ArgoCD version to install (default: $ARGOCD_VERSION)
    REPO_URL          Git repository URL (default: $REPO_URL)
    WAIT_TIMEOUT      Timeout for waiting on resources (default: $WAIT_TIMEOUT)

Examples:
    $0 local              # Bootstrap local ArgoCD
    $0 dev                # Bootstrap dev ArgoCD
    REPO_URL=https://github.com/myorg/ml-platform $0 prod

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v kustomize &> /dev/null; then
        missing_tools+=("kustomize")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites satisfied"
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus Operator CRDs first (required for monitoring)
    log_info "Installing Prometheus Operator CRDs..."
    if [ -f "${SCRIPT_DIR}/install-prometheus-crds.sh" ]; then
        "${SCRIPT_DIR}/install-prometheus-crds.sh" || log_warn "Failed to install Prometheus CRDs"
    else
        log_warn "Prometheus CRDs installation script not found"
    fi
    
    # Install ArgoCD using the official installation method
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=${WAIT_TIMEOUT}s -n argocd deployment/argocd-server
    kubectl wait --for=condition=available --timeout=${WAIT_TIMEOUT}s -n argocd deployment/argocd-repo-server
    
    # Wait for application controller (it's a StatefulSet in newer versions)
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout=${WAIT_TIMEOUT}s -n argocd statefulset/argocd-application-controller
    
    log_success "ArgoCD installed"
}

# Configure ArgoCD for local access
configure_argocd_local() {
    log_info "Configuring ArgoCD for local access..."
    
    # Patch ArgoCD server service to use NodePort for local access
    kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30080}]}}'
    
    # Disable TLS for local development
    kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
    
    # Restart ArgoCD server to apply changes
    kubectl rollout restart deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=${WAIT_TIMEOUT}s -n argocd deployment/argocd-server
    
    log_success "ArgoCD configured for local access"
}

# Configure repository
configure_repository() {
    log_info "Configuring repository: $REPO_URL"
    
    # Create repository secret
    kubectl create secret generic ml-platform-repo \
        --from-literal=url="$REPO_URL" \
        --from-literal=type=git \
        -n argocd \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Label the secret so ArgoCD picks it up
    kubectl label secret ml-platform-repo -n argocd \
        argocd.argoproj.io/secret-type=repository \
        --overwrite
    
    log_success "Repository configured"
}

# Deploy applications
deploy_applications() {
    log_info "Deploying ArgoCD Applications..."
    
    # Update application manifests with correct repo URL
    cd "$INFRA_DIR/kubernetes/base/gitops/applications"
    
    # Deploy application manifests based on environment
    if [ "$ENVIRONMENT" = "local" ]; then
        # For local environment, only deploy local-specific applications
        local_apps="ml-platform-local.yaml monitoring.yaml"
        for app in $local_apps; do
            if [ -f "$app" ]; then
                log_info "Configuring application: $app"
                sed "s|https://github.com/gigifokchiman/implement-ml-p|$REPO_URL|g" "$app" | kubectl apply -f -
            else
                log_warn "Application file not found: $app"
            fi
        done
    else
        # Deploy all applications for other environments
        for app in *.yaml; do
            if [[ "$app" == "kustomization.yaml" ]]; then
                continue
            fi
            
            log_info "Configuring application: $app"
            sed "s|https://github.com/gigifokchiman/implement-ml-p|$REPO_URL|g" "$app" | kubectl apply -f -
        done
    fi
    
    log_success "Applications deployed"
}

# Get ArgoCD admin password
get_admin_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    # Wait for secret to be created
    local retries=30
    while [ $retries -gt 0 ]; do
        if kubectl get secret -n argocd argocd-initial-admin-secret &> /dev/null; then
            break
        fi
        log_info "Waiting for admin secret... ($retries retries left)"
        sleep 5
        ((retries--))
    done
    
    if [ $retries -eq 0 ]; then
        log_warn "Admin secret not found, may need to be created manually"
        return
    fi
    
    local password
    password=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
    
    echo ""
    log_success "ArgoCD Admin Credentials:"
    echo "  Username: admin"
    echo "  Password: $password"
    echo ""
}

# Show access information
show_access_info() {
    log_info "ArgoCD Access Information"
    echo "=================================="
    
    case $ENVIRONMENT in
        "local")
            echo "ArgoCD UI: http://argocd.ml-platform.local:30080"
            echo "Add to /etc/hosts: 127.0.0.1 argocd.ml-platform.local"
            echo ""
            echo "Port forward (alternative):"
            echo "  kubectl port-forward -n argocd svc/argocd-server 8080:80"
            echo "  Then access: http://localhost:8080"
            ;;
        "dev"|"staging"|"prod")
            local service_type
            service_type=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.type}')
            
            if [[ "$service_type" == "LoadBalancer" ]]; then
                local external_ip
                external_ip=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                if [[ -n "$external_ip" ]]; then
                    echo "ArgoCD UI: https://$external_ip"
                else
                    echo "ArgoCD UI: Waiting for LoadBalancer external IP..."
                fi
            else
                echo "ArgoCD UI: Configure ingress or port-forward"
                echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
            fi
            ;;
    esac
    
    echo ""
    echo "CLI Login:"
    echo "  argocd login <argocd-server> --username admin --password <password>"
    echo ""
}

# Show next steps
show_next_steps() {
    echo ""
    log_info "Next Steps:"
    echo "1. Access ArgoCD UI using the information above"
    echo "2. Login with admin credentials"
    echo "3. Verify applications are syncing:"
    echo "   kubectl get applications -n argocd"
    echo "4. Check application status in ArgoCD UI"
    echo "5. Configure notifications (optional)"
    echo "6. Set up RBAC and user management"
    echo ""
    echo "Useful Commands:"
    echo "  kubectl get applications -n argocd"
    echo "  kubectl logs -n argocd deployment/argocd-application-controller"
    echo "  kubectl logs -n argocd deployment/argocd-server"
    echo ""
}

# Main execution
main() {
    log_info "Starting ArgoCD bootstrap for environment: $ENVIRONMENT"
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(local|dev|staging|prod)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        usage
        exit 1
    fi
    
    # Check if help requested
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        usage
        exit 0
    fi
    
    check_prerequisites
    install_argocd
    
    # Configure for local environment
    if [[ "$ENVIRONMENT" == "local" ]]; then
        configure_argocd_local
    fi
    
    configure_repository
    deploy_applications
    get_admin_password
    show_access_info
    show_next_steps
    
    log_success "ArgoCD bootstrap completed for $ENVIRONMENT!"
}

# Execute main function
main "$@"