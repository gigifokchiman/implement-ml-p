#!/bin/bash
# Template script to create new Kind clusters for applications
# Usage: ./new-cluster.sh <app-name> [port-offset]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME=${1:-}
PORT_OFFSET=${2:-10}  # Default offset of 10 from base ports (8080, 8443)

if [ -z "$APP_NAME" ]; then
    echo "❌ Error: Application name is required"
    echo "Usage: $0 <app-name> [port-offset]"
    echo "Example: $0 analytics-platform 20"
    exit 1
fi

# Validate app name (no spaces, lowercase, hyphens ok)
if ! [[ "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Error: App name must be lowercase alphanumeric with hyphens only"
    echo "Example: analytics-platform, user-service, data-processor"
    exit 1
fi

CLUSTER_NAME="${APP_NAME}-local"
BASE_HTTP_PORT=8080
BASE_HTTPS_PORT=8443
HTTP_PORT=$((BASE_HTTP_PORT + PORT_OFFSET))
HTTPS_PORT=$((BASE_HTTPS_PORT + PORT_OFFSET))

echo "🚀 Creating new Kind cluster for: $APP_NAME"
echo "📋 Configuration:"
echo "   Cluster name: $CLUSTER_NAME"
echo "   HTTP port: $HTTP_PORT"
echo "   HTTPS port: $HTTPS_PORT"
echo ""

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "⚠️  Cluster $CLUSTER_NAME already exists"
    echo "Do you want to delete and recreate it? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing cluster..."
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo "❌ Cancelled"
        exit 1
    fi
fi

# Create the cluster configuration
CLUSTER_CONFIG=$(cat <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
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
    hostPort: $HTTP_PORT
    protocol: TCP
  - containerPort: 443
    hostPort: $HTTPS_PORT
    protocol: TCP
- role: worker
EOF
)

# Create temporary config file
TEMP_CONFIG=$(mktemp)
echo "$CLUSTER_CONFIG" > "$TEMP_CONFIG"

echo "🔧 Creating Kind cluster..."
kind create cluster --config "$TEMP_CONFIG"

# Clean up temp file
rm "$TEMP_CONFIG"

echo "✅ Cluster created successfully!"
echo ""
echo "🎯 Next steps:"
echo "1. Switch to the new cluster context:"
echo "   kubectl config use-context kind-$CLUSTER_NAME"
echo ""
echo "2. Install storage provisioner:"
echo "   kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml"
echo ""
echo "3. Create your application namespaces:"
echo "   kubectl create namespace $APP_NAME"
echo ""
echo "4. Deploy your applications using:"
echo "   kubectl apply -k /path/to/your/manifests"
echo ""
echo "🌐 Access URLs will be:"
echo "   HTTP:  http://localhost:$HTTP_PORT"
echo "   HTTPS: https://localhost:$HTTPS_PORT"
echo ""
echo "📝 Useful commands:"
echo "   List all clusters:     kind get clusters"
echo "   Delete this cluster:   kind delete cluster --name $CLUSTER_NAME"
echo "   Get cluster info:      kubectl cluster-info --context kind-$CLUSTER_NAME"