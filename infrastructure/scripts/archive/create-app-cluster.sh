#!/bin/bash
# Create a new Kind cluster environment for an application using Terraform template
# Usage: ./create-app-cluster.sh <app-name> [http-port] [https-port]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME=${1:-}
HTTP_PORT=${2:-8100}
HTTPS_PORT=${3:-8453}

if [ -z "$APP_NAME" ]; then
    echo "❌ Error: Application name is required"
    echo "Usage: $0 <app-name> [http-port] [https-port]"
    echo "Examples:"
    echo "  $0 analytics-platform"
    echo "  $0 user-service 8110 8463"
    echo "  $0 notification-api 8120 8473"
    exit 1
fi

# Validate app name (no spaces, lowercase, hyphens ok)
if ! [[ "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Error: App name must be lowercase alphanumeric with hyphens only"
    echo "Example: analytics-platform, user-service, data-processor"
    exit 1
fi

CLUSTER_NAME="${APP_NAME}-local"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/$APP_NAME"
TEMPLATE_FILE="$SCRIPT_DIR/../terraform/templates/new-cluster-template.tf"

echo "🚀 Creating new cluster environment for: $APP_NAME"
echo "📋 Configuration:"
echo "   Cluster name: $CLUSTER_NAME"
echo "   HTTP port: $HTTP_PORT"
echo "   HTTPS port: $HTTPS_PORT"
echo "   Terraform dir: $TERRAFORM_DIR"
echo ""

# Check if environment already exists
if [ -d "$TERRAFORM_DIR" ]; then
    echo "⚠️  Environment directory $TERRAFORM_DIR already exists"
    echo "Do you want to overwrite it? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing existing directory..."
        rm -rf "$TERRAFORM_DIR"
    else
        echo "❌ Cancelled"
        exit 1
    fi
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$TERRAFORM_DIR"

# Copy template and customize
echo "📝 Setting up Terraform configuration..."
cp "$TEMPLATE_FILE" "$TERRAFORM_DIR/main.tf"

# Replace template variables
sed -i.bak "s/REPLACE_WITH_APP_NAME/$APP_NAME/g" "$TERRAFORM_DIR/main.tf"
sed -i.bak "s/default     = 8100/default     = $HTTP_PORT/g" "$TERRAFORM_DIR/main.tf"
sed -i.bak "s/default     = 8453/default     = $HTTPS_PORT/g" "$TERRAFORM_DIR/main.tf"
rm "$TERRAFORM_DIR/main.tf.bak"

# Create terraform.tfvars
cat > "$TERRAFORM_DIR/terraform.tfvars" <<EOF
# Configuration for $APP_NAME cluster
app_name   = "$APP_NAME"
http_port  = $HTTP_PORT
https_port = $HTTPS_PORT

# Customize these for your application
database_config = {
  username = "admin"
  password = "changeme123"
  database = "${APP_NAME//-/_}_db"
}

cache_config = {
  enabled = true
}

storage_config = {
  buckets = ["${APP_NAME}-data", "${APP_NAME}-artifacts", "${APP_NAME}-models"]
}
EOF

# Create variables file
cat > "$TERRAFORM_DIR/variables.tf" <<EOF
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "http_port" {
  description = "HTTP port for ingress"
  type        = number
}

variable "https_port" {
  description = "HTTPS port for ingress"
  type        = number
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    username = string
    password = string
    database = string
  })
}

variable "cache_config" {
  description = "Cache configuration"
  type = object({
    enabled = bool
  })
}

variable "storage_config" {
  description = "Storage configuration"
  type = object({
    buckets = list(string)
  })
}
EOF

# Create README
cat > "$TERRAFORM_DIR/README.md" <<EOF
# $APP_NAME Cluster

Local development cluster for the $APP_NAME application.

## Configuration

- **Cluster name**: $CLUSTER_NAME
- **HTTP port**: $HTTP_PORT
- **HTTPS port**: $HTTPS_PORT

## Usage

\`\`\`bash
# Initialize and apply
terraform init
terraform apply

# Switch to cluster context
kubectl config use-context kind-$CLUSTER_NAME

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Access services (port-forward examples)
kubectl port-forward -n database svc/postgres 5432:5432
kubectl port-forward -n cache svc/redis 6379:6379
kubectl port-forward -n storage svc/minio 9001:9000

# Clean up
terraform destroy
kind delete cluster --name $CLUSTER_NAME
\`\`\`

## Application URLs

- **Application**: http://localhost:$HTTP_PORT
- **MinIO**: http://localhost:9001 (admin/changeme123)
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

## Customization

Edit \`terraform.tfvars\` to customize:
- Database credentials
- Storage buckets
- Cache settings
- Resource limits

## Generated on $(date)
EOF

echo "🔧 Initializing Terraform..."
cd "$TERRAFORM_DIR"
terraform init

echo "📋 Planning deployment..."
terraform plan

echo ""
echo "✅ Environment created successfully!"
echo ""
echo "🎯 Next steps:"
echo "1. Review the configuration:"
echo "   cd $TERRAFORM_DIR"
echo "   cat terraform.tfvars"
echo ""
echo "2. Deploy the cluster:"
echo "   terraform apply"
echo ""
echo "3. Switch to the cluster:"
echo "   kubectl config use-context kind-$CLUSTER_NAME"
echo ""
echo "4. Deploy your application manifests:"
echo "   kubectl apply -f /path/to/your/manifests"
echo ""
echo "📁 Files created:"
echo "   $TERRAFORM_DIR/main.tf"
echo "   $TERRAFORM_DIR/variables.tf"
echo "   $TERRAFORM_DIR/terraform.tfvars"
echo "   $TERRAFORM_DIR/README.md"
echo ""
echo "🌐 Your application will be available at:"
echo "   http://localhost:$HTTP_PORT"