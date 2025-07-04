#!/bin/bash
# Helm-based platform deployment script
# Usage: ./helm-deploy-platform.sh <app-name> [cluster-name] [namespace]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME=${1:-}
CLUSTER_NAME=${2:-"${APP_NAME}-local"}
NAMESPACE=${3:-"$APP_NAME"}

if [ -z "$APP_NAME" ]; then
    echo "❌ Error: Application name is required"
    echo "Usage: $0 <app-name> [cluster-name] [namespace]"
    echo ""
    echo "Examples:"
    echo "  $0 analytics-platform"
    echo "  $0 user-service user-service-local user-service"
    echo "  $0 notification-api existing-cluster notifications"
    exit 1
fi

# Validate app name
if ! [[ "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Error: App name must be lowercase alphanumeric with hyphens only"
    exit 1
fi

CHART_DIR="$SCRIPT_DIR/../helm/charts/platform-template"
VALUES_DIR="$SCRIPT_DIR/../helm/values"
RELEASE_NAME="$APP_NAME"

echo "🚀 Deploying platform using Helm"
echo "📋 Configuration:"
echo "   App name: $APP_NAME"
echo "   Cluster: $CLUSTER_NAME"
echo "   Namespace: $NAMESPACE"
echo "   Release: $RELEASE_NAME"
echo "   Chart: $CHART_DIR"
echo ""

# Check if cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "⚠️  Cluster '$CLUSTER_NAME' not found. Creating it..."
    "$SCRIPT_DIR/new-cluster.sh" "$CLUSTER_NAME" 20
fi

# Switch to cluster context
CONTEXT_NAME="kind-$CLUSTER_NAME"
echo "🔄 Switching to cluster context: $CONTEXT_NAME"
kubectl config use-context "$CONTEXT_NAME"

# Create namespace if it doesn't exist
echo "📁 Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Update chart dependencies
echo "🔗 Updating chart dependencies..."
cd "$CHART_DIR"
helm dependency update

# Create custom values file for this deployment
VALUES_FILE="$VALUES_DIR/${APP_NAME}-values.yaml"
mkdir -p "$VALUES_DIR"

if [ ! -f "$VALUES_FILE" ]; then
    echo "📝 Creating custom values file: $VALUES_FILE"
    cat > "$VALUES_FILE" <<EOF
# Custom values for $APP_NAME platform
app:
  name: "$APP_NAME"
  namespace: "$NAMESPACE"
  version: "1.0.0"
  environment: "local"

# Database configuration
database:
  enabled: true
  postgresql:
    auth:
      database: "${APP_NAME//-/_}_db"
      username: "${APP_NAME//-/_}_user"
      password: "changeme123"

# Storage configuration  
storage:
  enabled: true
  minio:
    defaultBuckets: "${APP_NAME}-data,${APP_NAME}-artifacts,${APP_NAME}-models"

# Ingress configuration
ingress:
  enabled: true
  hosts:
    - host: "${APP_NAME}.local"
      paths:
        - path: /
          pathType: Prefix

# Application services (customize these for your app)
services:
  api:
    enabled: true
    image:
      repository: "nginx"  # Replace with your actual image
      tag: "alpine"
    port: 8080
    
  worker:
    enabled: false  # Enable if you need background workers

# Resource quotas for this application
resourceQuota:
  enabled: true
  hard:
    requests.cpu: "1"
    requests.memory: "2Gi"
    limits.cpu: "2"
    limits.memory: "4Gi"
    persistentvolumeclaims: "5"
    services: "5"
EOF

    echo "✅ Created custom values file. You can edit $VALUES_FILE to customize your deployment."
    echo ""
fi

# Deploy using Helm
echo "🚀 Deploying with Helm..."
helm upgrade --install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait \
    --timeout 10m

echo ""
echo "✅ Deployment successful!"
echo ""
echo "📊 Deployment Status:"
helm status "$RELEASE_NAME" --namespace "$NAMESPACE"

echo ""
echo "🎯 Next Steps:"
echo ""
echo "1. Check deployment status:"
echo "   kubectl get pods -n $NAMESPACE"
echo "   kubectl get services -n $NAMESPACE"
echo ""
echo "2. Access your application:"
echo "   kubectl port-forward -n $NAMESPACE svc/${APP_NAME}-api 8080:8080"
echo "   curl http://localhost:8080"
echo ""
echo "3. Access supporting services:"
echo "   # Database"
echo "   kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-postgresql 5432:5432"
echo "   # Cache"  
echo "   kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-redis-master 6379:6379"
echo "   # Storage"
echo "   kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-minio 9000:9000"
echo "   # Monitoring"
echo "   kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-prometheus-server 9090:80"
echo ""
echo "4. Customize your deployment:"
echo "   # Edit values file"
echo "   nano $VALUES_FILE"
echo "   # Upgrade deployment"
echo "   helm upgrade $RELEASE_NAME $CHART_DIR -n $NAMESPACE -f $VALUES_FILE"
echo ""
echo "5. Clean up when done:"
echo "   helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo "   kubectl delete namespace $NAMESPACE"
echo ""
echo "📁 Values file location: $VALUES_FILE"
echo "🌐 Application URL: http://${APP_NAME}.local (add to /etc/hosts)"