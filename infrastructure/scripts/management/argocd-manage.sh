#!/bin/bash

# ArgoCD Management Script
# Provides convenient commands for managing ArgoCD applications

set -euo pipefail

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="argocd"
ARGOCD_SERVER=""
ENVIRONMENT="${ENVIRONMENT:-local}"

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
Usage: $0 <command> [options]

ArgoCD Management Commands:

APPLICATIONS:
    list                    List all applications
    status <app>           Show application status
    diff <app>             Show differences between live and desired state
    sync <app>             Sync application
    refresh <app>          Refresh application
    rollback <app> <rev>   Rollback to specific revision
    delete <app>           Delete application
    logs <app>             Show application logs

CLUSTER:
    dashboard              Open ArgoCD dashboard
    login                  Login to ArgoCD CLI
    password               Get admin password
    apps                   Show all app status
    health                 Check ArgoCD health

TROUBLESHOOTING:
    debug <app>            Debug application issues
    events <app>           Show application events
    describe <app>         Describe application
    pods <app>             Show application pods

Environment Variables:
    ENVIRONMENT            Target environment (local, dev, staging, prod)
    ARGOCD_SERVER          ArgoCD server URL (auto-detected if not set)

Examples:
    $0 list                           # List all applications
    $0 status ml-platform-local       # Show app status
    $0 diff ml-platform-local         # Show configuration differences
    $0 sync ml-platform-local         # Sync application
    $0 dashboard                      # Open dashboard
    ENVIRONMENT=dev $0 login          # Login to dev ArgoCD

EOF
}

# Detect ArgoCD server
detect_argocd_server() {
    if [[ -n "$ARGOCD_SERVER" ]]; then
        return
    fi
    
    case $ENVIRONMENT in
        "local")
            ARGOCD_SERVER="localhost:8080"
            ;;
        "dev")
            ARGOCD_SERVER="argocd-dev.aws.com"
            ;;
        "staging")
            ARGOCD_SERVER="argocd-staging.aws.com"
            ;;
        "prod")
            ARGOCD_SERVER="argocd.company.com"
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Check if argocd CLI is available
check_argocd_cli() {
    if ! command -v argocd &> /dev/null; then
        log_warn "ArgoCD CLI not found. Install with:"
        echo "  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        echo "  chmod +x argocd && sudo mv argocd /usr/local/bin/"
        return 1
    fi
    return 0
}

# Get admin password
get_admin_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    if ! kubectl get secret -n $ARGOCD_NAMESPACE argocd-initial-admin-secret &> /dev/null; then
        log_error "Admin secret not found"
        return 1
    fi
    
    kubectl get secret -n $ARGOCD_NAMESPACE argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
}

# Login to ArgoCD
argocd_login() {
    detect_argocd_server
    
    if ! check_argocd_cli; then
        return 1
    fi
    
    # For local environment, ensure port forwarding is active
    if [[ "$ENVIRONMENT" == "local" ]]; then
        if ! pgrep -f "kubectl port-forward.*argocd.*8080" > /dev/null; then
            log_info "Starting port forward to ArgoCD..."
            kubectl port-forward -n argocd svc/argocd-server 8080:80 > /dev/null 2>&1 &
            sleep 2  # Give it a moment to start
        fi
    fi
    
    log_info "Logging into ArgoCD server: $ARGOCD_SERVER"
    
    local password
    if ! password=$(get_admin_password); then
        return 1
    fi
    
    if [[ "$ENVIRONMENT" == "local" ]]; then
        argocd login "$ARGOCD_SERVER" --username admin --password "$password" --insecure
    else
        argocd login "$ARGOCD_SERVER" --username admin --password "$password"
    fi
    
    log_success "Logged into ArgoCD"
}

# List applications
list_applications() {
    log_info "ArgoCD Applications:"
    kubectl get applications -n $ARGOCD_NAMESPACE -o custom-columns="NAME:.metadata.name,STATUS:.status.health.status,SYNC:.status.sync.status,REPO:.spec.source.repoURL,PATH:.spec.source.path"
}

# Show application status
app_status() {
    local app_name="$1"
    
    if ! kubectl get application -n $ARGOCD_NAMESPACE "$app_name" &> /dev/null; then
        log_error "Application '$app_name' not found"
        return 1
    fi
    
    log_info "Application Status: $app_name"
    echo "=================================="
    
    kubectl get application -n $ARGOCD_NAMESPACE "$app_name" -o yaml | grep -A 20 "status:" | head -30
    
    echo ""
    log_info "Recent Events:"
    kubectl get events -n $ARGOCD_NAMESPACE --field-selector involvedObject.name="$app_name" --sort-by='.lastTimestamp' | tail -10
}

# Sync application
sync_application() {
    local app_name="$1"
    
    log_info "Syncing application: $app_name"
    
    # Use kubectl instead of argocd CLI for reliability
    kubectl patch application -n $ARGOCD_NAMESPACE "$app_name" --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'
    
    log_success "Sync initiated for $app_name"
    
    # Show sync status
    log_info "Checking sync status..."
    sleep 3
    kubectl get application -n $ARGOCD_NAMESPACE "$app_name" -o jsonpath='{.status.sync.status}'
    echo
}

# Refresh application
refresh_application() {
    local app_name="$1"
    
    log_info "Refreshing application: $app_name"
    
    # Use kubectl to trigger refresh
    kubectl patch application -n $ARGOCD_NAMESPACE "$app_name" --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"'$(date +%s)'"}}}'
    
    log_success "Refresh initiated for $app_name"
}

# Rollback application
rollback_application() {
    local app_name="$1"
    local revision="$2"
    
    log_info "Rolling back application '$app_name' to revision '$revision'"
    
    if ! check_argocd_cli; then
        log_error "ArgoCD CLI required for rollback"
        return 1
    fi
    
    argocd app rollback "$app_name" "$revision"
    
    log_success "Rollback initiated for $app_name"
}

# Delete application
delete_application() {
    local app_name="$1"
    
    log_warn "This will delete application '$app_name' and all its resources!"
    read -p "Are you sure? Type 'yes' to continue: " -r
    
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Delete cancelled"
        return 0
    fi
    
    log_info "Deleting application: $app_name"
    kubectl delete application -n $ARGOCD_NAMESPACE "$app_name"
    
    log_success "Application deleted: $app_name"
}

# Show application logs
app_logs() {
    local app_name="$1"
    
    log_info "Recent logs for application: $app_name"
    
    if check_argocd_cli; then
        argocd app logs "$app_name" --tail 50
    else
        # Fallback: show controller logs for this app
        kubectl logs -n $ARGOCD_NAMESPACE deployment/argocd-application-controller | grep "$app_name" | tail -20
    fi
}

# Open dashboard
open_dashboard() {
    detect_argocd_server
    
    log_info "Opening ArgoCD Dashboard..."
    
    case $ENVIRONMENT in
        "local")
            # Check if port forward is already running
            if pgrep -f "kubectl port-forward.*argocd.*8080" > /dev/null; then
                log_info "Port forward already running"
            else
                log_info "Starting background port forward to ArgoCD..."
                kubectl port-forward -n argocd svc/argocd-server 8080:80 > /dev/null 2>&1 &
                sleep 2  # Give it a moment to start
            fi
            
            echo "Dashboard URL: http://localhost:8080"
            echo "Username: admin"
            echo "Password: $(get_admin_password 2>/dev/null || echo 'Run: $0 password')"
            echo ""
            echo "To stop port forwarding: pkill -f 'kubectl port-forward.*argocd'"
            
            # Open browser
            if command -v open &> /dev/null; then
                open "http://localhost:8080"
            elif command -v xdg-open &> /dev/null; then
                xdg-open "http://localhost:8080"
            fi
            ;;
        *)
            echo "Dashboard URL: https://$ARGOCD_SERVER"
            if command -v open &> /dev/null; then
                open "https://$ARGOCD_SERVER"
            elif command -v xdg-open &> /dev/null; then
                xdg-open "https://$ARGOCD_SERVER"
            fi
            echo "Username: admin"
            echo "Password: $(get_admin_password 2>/dev/null || echo 'Run: $0 password')"
            ;;
    esac
}

# Show all apps status
show_all_apps() {
    log_info "All Applications Status:"
    echo "=================================="
    
    kubectl get applications -n $ARGOCD_NAMESPACE --no-headers | while read -r line; do
        local app_name
        app_name=$(echo "$line" | awk '{print $1}')
        local health
        health=$(echo "$line" | awk '{print $2}')
        local sync
        sync=$(echo "$line" | awk '{print $3}')
        
        printf "%-20s Health: %-10s Sync: %-10s\n" "$app_name" "$health" "$sync"
    done
}

# Check ArgoCD health
check_health() {
    log_info "ArgoCD Health Check:"
    echo "=================================="
    
    echo "ArgoCD Pods:"
    kubectl get pods -n $ARGOCD_NAMESPACE
    
    echo ""
    echo "ArgoCD Services:"
    kubectl get svc -n $ARGOCD_NAMESPACE
    
    echo ""
    echo "Application Status:"
    show_all_apps
}

# Debug application
debug_application() {
    local app_name="$1"
    
    log_info "Debugging application: $app_name"
    echo "=================================="
    
    # Application details
    echo "Application Details:"
    kubectl describe application -n $ARGOCD_NAMESPACE "$app_name"
    
    echo ""
    echo "Application Events:"
    kubectl get events -n $ARGOCD_NAMESPACE --field-selector involvedObject.name="$app_name"
    
    echo ""
    echo "ArgoCD Controller Logs (recent):"
    kubectl logs -n $ARGOCD_NAMESPACE deployment/argocd-application-controller --tail=50 | grep "$app_name"
}

# Show application events
app_events() {
    local app_name="$1"
    
    log_info "Events for application: $app_name"
    kubectl get events -n $ARGOCD_NAMESPACE --field-selector involvedObject.name="$app_name" --sort-by='.lastTimestamp'
}

# Describe application
describe_application() {
    local app_name="$1"
    
    log_info "Describing application: $app_name"
    kubectl describe application -n $ARGOCD_NAMESPACE "$app_name"
}

# Show application pods
app_pods() {
    local app_name="$1"
    
    # Get target namespace from application
    local target_namespace
    target_namespace=$(kubectl get application -n $ARGOCD_NAMESPACE "$app_name" -o jsonpath='{.spec.destination.namespace}')
    
    if [[ -z "$target_namespace" ]]; then
        log_error "Could not determine target namespace for $app_name"
        return 1
    fi
    
    log_info "Pods for application '$app_name' in namespace '$target_namespace':"
    kubectl get pods -n "$target_namespace" -l argocd.argoproj.io/instance="$app_name"
}

# Show application diff
app_diff() {
    local app_name="$1"
    
    if [[ -z "$app_name" ]]; then
        log_error "Application name is required"
        return 1
    fi
    
    log_info "Showing differences for application: $app_name"
    
    if ! check_argocd_cli; then
        log_error "ArgoCD CLI is required for diff command"
        return 1
    fi
    
    # Ensure we're logged in
    if ! argocd context 2>/dev/null | grep -q "$ARGOCD_SERVER"; then
        log_warn "Not logged in to ArgoCD, attempting login..."
        if ! argocd_login; then
            log_error "Failed to login to ArgoCD"
            return 1
        fi
    fi
    
    # Show the diff
    argocd app diff "$app_name"
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case $command in
        "list")
            list_applications
            ;;
        "status")
            app_status "${2:-}"
            ;;
        "diff")
            app_diff "${2:-}"
            ;;
        "sync")
            sync_application "${2:-}"
            ;;
        "refresh")
            refresh_application "${2:-}"
            ;;
        "rollback")
            rollback_application "${2:-}" "${3:-}"
            ;;
        "delete")
            delete_application "${2:-}"
            ;;
        "logs")
            app_logs "${2:-}"
            ;;
        "dashboard")
            open_dashboard
            ;;
        "login")
            argocd_login
            ;;
        "password")
            get_admin_password
            ;;
        "apps")
            show_all_apps
            ;;
        "health")
            check_health
            ;;
        "debug")
            debug_application "${2:-}"
            ;;
        "events")
            app_events "${2:-}"
            ;;
        "describe")
            describe_application "${2:-}"
            ;;
        "pods")
            app_pods "${2:-}"
            ;;
        "help"|"--help"|"-h")
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"