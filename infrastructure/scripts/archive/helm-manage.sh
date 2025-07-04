#!/bin/bash
# Helm-based platform management script
# Usage: ./helm-manage.sh <command> [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_DIR="$SCRIPT_DIR/../helm/values"
CHART_DIR="$SCRIPT_DIR/../helm/charts/platform-template"

show_help() {
    cat <<EOF
⚓ Helm Platform Management Tool

USAGE:
    $0 <command> [options]

COMMANDS:
    deploy <app-name>              Deploy a new platform
    upgrade <app-name>             Upgrade existing platform
    rollback <app-name> [revision] Rollback to previous version
    delete <app-name>              Delete platform deployment
    status <app-name>              Show deployment status
    history <app-name>             Show deployment history
    values <app-name>              Show current values
    list                           List all deployments
    logs <app-name> [service]      Show logs for services
    test <app-name>                Run helm tests

DEPLOYMENT EXAMPLES:
    $0 deploy analytics-platform
    $0 deploy user-service
    $0 upgrade analytics-platform
    $0 rollback analytics-platform 2
    $0 delete analytics-platform

MANAGEMENT EXAMPLES:
    $0 list
    $0 status analytics-platform
    $0 history analytics-platform
    $0 logs analytics-platform api

ADVANCED:
    # Deploy with custom cluster and namespace
    APP_CLUSTER=my-cluster APP_NAMESPACE=custom ./helm-manage.sh deploy my-app
    
    # Deploy with custom values
    $0 deploy my-app --set app.version=2.0.0 --set database.enabled=false

EOF
}

get_app_config() {
    local app_name="$1"
    local cluster_name="${APP_CLUSTER:-${app_name}-local}"
    local namespace="${APP_NAMESPACE:-$app_name}"
    local release_name="$app_name"
    local values_file="$VALUES_DIR/${app_name}-values.yaml"
    
    echo "$cluster_name|$namespace|$release_name|$values_file"
}

deploy_platform() {
    local app_name="$1"
    shift  # Remove app_name from arguments
    local extra_args="$@"
    
    if [ -z "$app_name" ]; then
        echo "❌ Error: Application name is required"
        echo "Usage: $0 deploy <app-name>"
        return 1
    fi
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    echo "🚀 Deploying platform: $app_name"
    echo "   Cluster: $cluster_name"
    echo "   Namespace: $namespace"
    echo "   Release: $release_name"
    echo ""
    
    # Check if cluster exists
    if ! kind get clusters | grep -q "^${cluster_name}$"; then
        echo "⚠️  Cluster '$cluster_name' not found. Creating it..."
        "$SCRIPT_DIR/new-cluster.sh" "$cluster_name" 20
    fi
    
    # Switch context
    kubectl config use-context "kind-$cluster_name"
    
    # Create namespace
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    
    # Add repos and update dependencies
    echo "📦 Setting up Helm repositories..."
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update
    
    cd "$CHART_DIR"
    helm dependency update
    
    # Create values file if it doesn't exist
    if [ ! -f "$values_file" ]; then
        echo "📝 Creating values file: $values_file"
        mkdir -p "$VALUES_DIR"
        cat > "$values_file" <<EOF
app:
  name: "$app_name"
  namespace: "$namespace"
  environment: "local"

database:
  postgresql:
    auth:
      database: "${app_name//-/_}_db"
      username: "${app_name//-/_}_user"

storage:
  minio:
    defaultBuckets: "${app_name}-data,${app_name}-artifacts"

ingress:
  hosts:
    - host: "${app_name}.local"
      paths:
        - path: /
          pathType: Prefix
EOF
    fi
    
    # Deploy
    echo "🚀 Installing/upgrading with Helm..."
    helm upgrade --install "$release_name" . \
        --namespace "$namespace" \
        --values "$values_file" \
        --wait \
        --timeout 10m \
        $extra_args
    
    echo "✅ Deployment successful!"
    show_post_deploy_info "$app_name"
}

upgrade_platform() {
    local app_name="$1"
    shift
    local extra_args="$@"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    echo "⬆️  Upgrading platform: $app_name"
    
    kubectl config use-context "kind-$cluster_name"
    
    cd "$CHART_DIR"
    helm dependency update
    
    helm upgrade "$release_name" . \
        --namespace "$namespace" \
        --values "$values_file" \
        --wait \
        --timeout 10m \
        $extra_args
    
    echo "✅ Upgrade successful!"
    show_post_deploy_info "$app_name"
}

rollback_platform() {
    local app_name="$1"
    local revision="${2:-0}"  # 0 means previous version
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    echo "⏪ Rolling back platform: $app_name to revision $revision"
    
    kubectl config use-context "kind-$cluster_name"
    
    helm rollback "$release_name" $revision --namespace "$namespace" --wait
    
    echo "✅ Rollback successful!"
}

delete_platform() {
    local app_name="$1"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    echo "🗑️  Deleting platform: $app_name"
    echo "This will remove all resources in namespace: $namespace"
    echo "Are you sure? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        kubectl config use-context "kind-$cluster_name"
        
        helm uninstall "$release_name" --namespace "$namespace" || true
        kubectl delete namespace "$namespace" --ignore-not-found=true
        
        # Optionally remove values file
        if [ -f "$values_file" ]; then
            echo "Remove values file $values_file? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm "$values_file"
                echo "🗑️  Removed values file"
            fi
        fi
        
        echo "✅ Platform deleted"
    else
        echo "❌ Cancelled"
    fi
}

show_status() {
    local app_name="$1"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    echo "📊 Status for platform: $app_name"
    
    kubectl config use-context "kind-$cluster_name"
    
    echo ""
    echo "🎯 Helm Release Status:"
    helm status "$release_name" --namespace "$namespace"
    
    echo ""
    echo "🗃️  Kubernetes Resources:"
    kubectl get all -n "$namespace"
}

show_history() {
    local app_name="$1"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    kubectl config use-context "kind-$cluster_name"
    
    echo "📜 Deployment history for: $app_name"
    helm history "$release_name" --namespace "$namespace"
}

show_values() {
    local app_name="$1"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    kubectl config use-context "kind-$cluster_name"
    
    echo "⚙️  Current values for: $app_name"
    helm get values "$release_name" --namespace "$namespace"
}

list_deployments() {
    echo "📋 All Helm deployments:"
    echo ""
    
    kind get clusters | while read -r cluster; do
        echo "🔹 Cluster: $cluster"
        kubectl config use-context "kind-$cluster" 2>/dev/null || continue
        
        # Get all namespaces and check for helm releases
        kubectl get namespaces -o name | cut -d/ -f2 | while read -r ns; do
            if [ "$ns" = "default" ] || [ "$ns" = "kube-system" ] || [ "$ns" = "kube-public" ] || [ "$ns" = "kube-node-lease" ]; then
                continue
            fi
            
            releases=$(helm list -n "$ns" -q 2>/dev/null || true)
            if [ -n "$releases" ]; then
                echo "   Namespace: $ns"
                helm list -n "$ns" | tail -n +2 | while read -r line; do
                    echo "     $line"
                done
            fi
        done
        echo ""
    done
}

show_logs() {
    local app_name="$1"
    local service="${2:-api}"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    kubectl config use-context "kind-$cluster_name"
    
    echo "📜 Logs for $app_name/$service:"
    kubectl logs -n "$namespace" -l "app.kubernetes.io/name=${app_name}-${service}" --tail=100 -f
}

run_tests() {
    local app_name="$1"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    kubectl config use-context "kind-$cluster_name"
    
    echo "🧪 Running tests for: $app_name"
    helm test "$release_name" --namespace "$namespace"
}

show_post_deploy_info() {
    local app_name="$1"
    
    IFS='|' read -r cluster_name namespace release_name values_file <<< "$(get_app_config "$app_name")"
    
    echo ""
    echo "🎯 Platform deployed successfully!"
    echo ""
    echo "📊 Quick status check:"
    kubectl get pods -n "$namespace" | head -10
    echo ""
    echo "🔗 Useful commands:"
    echo "   Status:    $0 status $app_name"
    echo "   Logs:      $0 logs $app_name api"
    echo "   Upgrade:   $0 upgrade $app_name"
    echo "   Delete:    $0 delete $app_name"
    echo ""
    echo "📝 Values file: $values_file"
}

# Main command handling
case "${1:-help}" in
    deploy)
        deploy_platform "${@:2}"
        ;;
    upgrade)
        upgrade_platform "${@:2}"
        ;;
    rollback)
        rollback_platform "${@:2}"
        ;;
    delete|remove)
        delete_platform "$2"
        ;;
    status)
        show_status "$2"
        ;;
    history)
        show_history "$2"
        ;;
    values)
        show_values "$2"
        ;;
    list|ls)
        list_deployments
        ;;
    logs)
        show_logs "$2" "$3"
        ;;
    test)
        run_tests "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac