#!/bin/bash
# Cluster management utility for multiple Kind clusters
# Usage: ./manage-clusters.sh <command> [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat <<EOF
🎛️  Kind Cluster Management Tool

USAGE:
    $0 <command> [options]

COMMANDS:
    list                    List all Kind clusters
    create <app-name>       Create a new cluster for an application
    delete <cluster-name>   Delete a specific cluster  
    switch <cluster-name>   Switch kubectl context to cluster
    status [cluster-name]   Show cluster status (all or specific)
    ports                   Show port mappings for all clusters
    cleanup                 Delete all clusters
    export <cluster-name>   Export cluster kubeconfig
    
EXAMPLES:
    $0 list
    $0 create analytics-platform
    $0 delete analytics-platform-local
    $0 switch ml-platform-local
    $0 status
    $0 ports
    $0 cleanup

For creating clusters with custom ports:
    $0 create user-service 8110 8463

EOF
}

list_clusters() {
    echo "📋 Kind Clusters:"
    if ! kind get clusters 2>/dev/null | grep -q .; then
        echo "   No clusters found"
        return
    fi
    
    echo ""
    kind get clusters | while read -r cluster; do
        # Get current context
        current_context=$(kubectl config current-context 2>/dev/null || echo "none")
        marker=""
        if [ "$current_context" = "kind-$cluster" ]; then
            marker=" ← current"
        fi
        
        echo "   🔹 $cluster$marker"
        
        # Try to get node info
        if kubectl --context "kind-$cluster" get nodes --no-headers 2>/dev/null | grep -q Ready; then
            node_count=$(kubectl --context "kind-$cluster" get nodes --no-headers 2>/dev/null | wc -l)
            echo "      Status: ✅ Ready ($node_count nodes)"
        else
            echo "      Status: ❌ Not ready"
        fi
        
        # Get port mappings if available
        if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "$cluster-control-plane"; then
            ports=$(docker ps --format "{{.Ports}}" --filter "name=$cluster-control-plane" | head -1)
            if [ -n "$ports" ]; then
                echo "      Ports: $ports"
            fi
        fi
        echo ""
    done
}

create_cluster() {
    local app_name="$1"
    local http_port="$2"
    local https_port="$3"
    
    if [ -z "$app_name" ]; then
        echo "❌ Error: Application name is required"
        echo "Usage: $0 create <app-name> [http-port] [https-port]"
        return 1
    fi
    
    echo "🚀 Creating cluster for: $app_name"
    if [ -n "$http_port" ] && [ -n "$https_port" ]; then
        "$SCRIPT_DIR/create-app-cluster.sh" "$app_name" "$http_port" "$https_port"
    else
        "$SCRIPT_DIR/create-app-cluster.sh" "$app_name"
    fi
}

delete_cluster() {
    local cluster_name="$1"
    
    if [ -z "$cluster_name" ]; then
        echo "❌ Error: Cluster name is required"
        echo "Usage: $0 delete <cluster-name>"
        return 1
    fi
    
    # Remove -local suffix if not provided
    if [[ ! "$cluster_name" =~ -local$ ]]; then
        cluster_name="${cluster_name}-local"
    fi
    
    if ! kind get clusters | grep -q "^${cluster_name}$"; then
        echo "❌ Error: Cluster '$cluster_name' not found"
        echo "Available clusters:"
        kind get clusters | sed 's/^/   /'
        return 1
    fi
    
    echo "🗑️  Deleting cluster: $cluster_name"
    echo "Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        kind delete cluster --name "$cluster_name"
        echo "✅ Cluster deleted"
        
        # Clean up terraform if it exists
        terraform_dir="$SCRIPT_DIR/../terraform/environments/${cluster_name%-local}"
        if [ -d "$terraform_dir" ]; then
            echo "🧹 Cleaning up Terraform state..."
            cd "$terraform_dir"
            terraform destroy -auto-approve 2>/dev/null || true
            rm -rf .terraform terraform.tfstate* .terraform.lock.hcl
        fi
    else
        echo "❌ Cancelled"
    fi
}

switch_cluster() {
    local cluster_name="$1"
    
    if [ -z "$cluster_name" ]; then
        echo "❌ Error: Cluster name is required"
        echo "Usage: $0 switch <cluster-name>"
        return 1
    fi
    
    # Remove -local suffix if not provided
    if [[ ! "$cluster_name" =~ -local$ ]]; then
        cluster_name="${cluster_name}-local"
    fi
    
    local context_name="kind-$cluster_name"
    
    if ! kubectl config get-contexts -o name | grep -q "^${context_name}$"; then
        echo "❌ Error: Context '$context_name' not found"
        echo "Available contexts:"
        kubectl config get-contexts -o name | grep "^kind-" | sed 's/^/   /'
        return 1
    fi
    
    echo "🔄 Switching to cluster: $cluster_name"
    kubectl config use-context "$context_name"
    echo "✅ Switched to $cluster_name"
    
    # Show basic cluster info
    echo ""
    echo "📊 Cluster info:"
    kubectl cluster-info | head -2
    kubectl get nodes
}

show_status() {
    local cluster_name="$1"
    
    if [ -n "$cluster_name" ]; then
        # Show specific cluster
        if [[ ! "$cluster_name" =~ -local$ ]]; then
            cluster_name="${cluster_name}-local"
        fi
        
        local context_name="kind-$cluster_name"
        echo "📊 Status for cluster: $cluster_name"
        kubectl --context "$context_name" get nodes
        echo ""
        kubectl --context "$context_name" get pods --all-namespaces
    else
        # Show all clusters
        echo "📊 Status for all clusters:"
        echo ""
        kind get clusters | while read -r cluster; do
            echo "🔹 Cluster: $cluster"
            kubectl --context "kind-$cluster" get nodes 2>/dev/null || echo "   ❌ Not accessible"
            echo ""
        done
    fi
}

show_ports() {
    echo "🌐 Port mappings for all clusters:"
    echo ""
    
    if ! docker ps | grep -q "kindest/node"; then
        echo "   No Kind clusters running"
        return
    fi
    
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "control-plane" | while read -r line; do
        cluster_name=$(echo "$line" | cut -d'-' -f1)
        ports=$(echo "$line" | cut -f2)
        echo "🔹 $cluster_name"
        echo "   Ports: $ports"
        echo ""
    done
}

cleanup_all() {
    echo "🧹 This will delete ALL Kind clusters"
    echo "Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        kind get clusters | while read -r cluster; do
            echo "🗑️  Deleting: $cluster"
            kind delete cluster --name "$cluster"
        done
        echo "✅ All clusters deleted"
    else
        echo "❌ Cancelled"
    fi
}

export_kubeconfig() {
    local cluster_name="$1"
    
    if [ -z "$cluster_name" ]; then
        echo "❌ Error: Cluster name is required"
        echo "Usage: $0 export <cluster-name>"
        return 1
    fi
    
    # Remove -local suffix if not provided
    if [[ ! "$cluster_name" =~ -local$ ]]; then
        cluster_name="${cluster_name}-local"
    fi
    
    local output_file="${cluster_name}-kubeconfig.yaml"
    
    echo "📤 Exporting kubeconfig for: $cluster_name"
    kind get kubeconfig --name "$cluster_name" > "$output_file"
    echo "✅ Kubeconfig exported to: $output_file"
    echo ""
    echo "To use this kubeconfig:"
    echo "   export KUBECONFIG=$PWD/$output_file"
    echo "   kubectl get nodes"
}

# Main command handling
case "${1:-help}" in
    list|ls)
        list_clusters
        ;;
    create|new)
        create_cluster "$2" "$3" "$4"
        ;;
    delete|del|rm)
        delete_cluster "$2"
        ;;
    switch|use)
        switch_cluster "$2"
        ;;
    status|info)
        show_status "$2"
        ;;
    ports)
        show_ports
        ;;
    cleanup|clean)
        cleanup_all
        ;;
    export)
        export_kubeconfig "$2"
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