#!/bin/bash
# Simple deployment script: Terraform for core + Helm for apps
# Usage: ./deploy-new-app.sh <app-name> [http-port] [https-port]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME=${1:-}
HTTP_PORT=${2:-8080}
HTTPS_PORT=${3:-8443}

if [ -z "$APP_NAME" ]; then
    echo "❌ Error: Application name is required"
    echo "Usage: $0 <app-name> [http-port] [https-port]"
    echo "Example: $0 analytics-platform 8110 8463"
    exit 1
fi

# Validate app name
if ! [[ "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Error: App name must be lowercase alphanumeric with hyphens only"
    exit 1
fi

TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/$APP_NAME"
HELM_CHART_DIR="$SCRIPT_DIR/../helm/charts/platform-template"
HELM_VALUES_DIR="$SCRIPT_DIR/../helm/values"

echo "🚀 Deploying new application: $APP_NAME"
echo "📋 Configuration:"
echo "   App name: $APP_NAME"
echo "   HTTP port: $HTTP_PORT"
echo "   HTTPS port: $HTTPS_PORT"
echo ""

# Step 1: Create Terraform environment
echo "🔧 Step 1: Creating core infrastructure with Terraform..."

if [ -d "$TERRAFORM_DIR" ]; then
    echo "⚠️  Directory $TERRAFORM_DIR already exists. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled"
        exit 1
    fi
else
    mkdir -p "$TERRAFORM_DIR"
fi

# Copy template and customize
cp "$SCRIPT_DIR/../terraform/environments/template"/* "$TERRAFORM_DIR/"

# Create terraform.tfvars
cat > "$TERRAFORM_DIR/terraform.tfvars" <<EOF
app_name   = "$APP_NAME"
http_port  = $HTTP_PORT
https_port = $HTTPS_PORT
EOF

# Initialize and apply Terraform
cd "$TERRAFORM_DIR"
echo "📦 Initializing Terraform..."
terraform init

echo "🏗️  Creating infrastructure..."
terraform apply -auto-approve

# Get cluster info
CLUSTER_NAME=$(terraform output -raw cluster_info | jq -r '.name')
NAMESPACE=$(terraform output -raw cluster_info | jq -r '.namespace')
CONTEXT=$(terraform output -raw cluster_info | jq -r '.context')

echo "✅ Infrastructure created!"
echo "   Cluster: $CLUSTER_NAME"
echo "   Namespace: $NAMESPACE"
echo ""

# Step 2: Deploy application with Helm
echo "⚓ Step 2: Deploying application with Helm..."

# Switch to the cluster context
kubectl config use-context "$CONTEXT"

# Create Helm values file
VALUES_FILE="$HELM_VALUES_DIR/${APP_NAME}-values.yaml"
mkdir -p "$HELM_VALUES_DIR"

cat > "$VALUES_FILE" <<EOF
# Values for $APP_NAME
app:
  name: "$APP_NAME"
  namespace: "$NAMESPACE"
  environment: "local"

# Database
database:
  enabled: true
  postgresql:
    auth:
      database: "${APP_NAME//-/_}_db"
      username: "${APP_NAME//-/_}_user"
      password: "changeme123"

# Cache  
cache:
  enabled: true
  redis:
    auth:
      enabled: false

# Storage
storage:
  enabled: true
  minio:
    auth:
      rootUser: "admin"
      rootPassword: "changeme123"
    defaultBuckets: "${APP_NAME}-data,${APP_NAME}-artifacts"

# Monitoring
monitoring:
  enabled: false  # Keep it simple

# Application
services:
  api:
    enabled: true
    image:
      repository: "nginx"
      tag: "alpine"
    port: 8080

# Ingress
ingress:
  enabled: true
  hosts:
    - host: "${APP_NAME}.local"
      paths:
        - path: /
          pathType: Prefix
EOF

# Add Helm repos
echo "📦 Setting up Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Update chart dependencies
cd "$HELM_CHART_DIR"
helm dependency update

# Deploy with Helm
echo "🚀 Deploying application..."
helm upgrade --install "$APP_NAME" . \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait \
    --timeout 10m

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Status:"
kubectl get pods -n "$NAMESPACE"
echo ""
echo "🌐 Access your application:"
echo "   URL: http://localhost:$HTTP_PORT"
echo "   Add to /etc/hosts: 127.0.0.1 ${APP_NAME}.local"
echo ""
echo "🔧 Useful commands:"
echo "   Switch context:  kubectl config use-context $CONTEXT"
echo "   Check status:    kubectl get pods -n $NAMESPACE"
echo "   Helm status:     helm status $APP_NAME -n $NAMESPACE"
echo "   Port forward:    kubectl port-forward -n $NAMESPACE svc/${APP_NAME}-api 8080:8080"
echo ""
echo "🗑️  Cleanup:"
echo "   Helm:       helm uninstall $APP_NAME -n $NAMESPACE"  
echo "   Terraform:  cd $TERRAFORM_DIR && terraform destroy"
echo "   Cluster:    kind delete cluster --name $CLUSTER_NAME"
echo ""
echo "📁 Files created:"
echo "   Terraform: $TERRAFORM_DIR"
echo "   Helm values: $VALUES_FILE"