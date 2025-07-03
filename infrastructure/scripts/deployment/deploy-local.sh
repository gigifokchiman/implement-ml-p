#!/bin/bash
# Comprehensive local ML Platform deployment script
# Handles both provider issues and deployment problems with storage fixes

set -e

echo "🚀 ML Platform Local Deployment Script"
echo "======================================"

# Function to clean up existing resources
cleanup_existing() {
    echo "🧹 Cleaning up existing resources..."
    
    # Delete existing Kind cluster if it exists
    if kind get clusters | grep -q ml-platform-local; then
        echo "🗑️  Deleting existing Kind cluster..."
        kind delete cluster --name ml-platform-local
    fi
    
    # Clean up Terraform state completely
    echo "🧹 Cleaning Terraform state..."
    rm -rf .terraform terraform.tfstate* .terraform.lock.hcl
    
    echo "✅ Cleanup complete"
}

# Function to install and configure storage provisioner
setup_storage_provisioner() {
    echo "💾 Setting up storage provisioner..."
    
    # Install local-path-provisioner if not present
    if ! kubectl get deployment -n local-path-storage local-path-provisioner 2>/dev/null; then
        echo "📦 Installing local-path-provisioner..."
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    fi
    
    # Wait for provisioner to be ready
    echo "⏳ Waiting for provisioner to be ready..."
    kubectl wait --for=condition=ready pod -n local-path-storage -l app=local-path-provisioner --timeout=120s
    
    # Remove any conflicting storage classes
    kubectl delete storageclass standard --ignore-not-found=true
    
    # Create proper storage class
    echo "💾 Creating storage class..."
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
    
    echo "✅ Storage provisioner configured!"
}

# Parse command line arguments
CLEANUP_FIRST=false
for arg in "$@"; do
    case $arg in
        --clean-first|--cleanup-first)
            CLEANUP_FIRST=true
            shift
            ;;
        *)
            # Unknown option
            ;;
    esac
done

# Get script directory and terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform/environments/local"

cd "$TERRAFORM_DIR"
echo "📍 Working in: $(pwd)"

# Run cleanup if requested
if [ "$CLEANUP_FIRST" = true ]; then
    cleanup_existing
fi

# Step 1: Initialize Terraform (standard providers)
echo ""
echo "🔧 Step 1: Setting up Terraform..."

# Clean up any existing terraform state to ensure fresh start
echo "🧹 Cleaning Terraform state..."
rm -f .terraform.lock.hcl
rm -rf .terraform

# Initialize Terraform (it will download providers automatically)
echo "🔄 Initializing Terraform..."
terraform init --upgrade

echo "✅ Terraform provider setup complete"

# Step 2: Create Kind cluster first
echo ""
echo "🐳 Step 2: Creating Kind cluster..."
terraform apply -target=kind_cluster.default -auto-approve

# Set kubectl context
echo "🔧 Configuring kubectl context..."
kubectl config use-context kind-ml-platform-local

# Step 3: No storage setup needed (using emptyDir volumes)
echo ""
echo "💾 Step 3: Using emptyDir volumes (no persistent storage needed for local dev)"

# Step 4: Deploy the platform
echo ""
echo "🏗️  Step 4: Deploying ML Platform..."

# Run terraform apply - should work now with proper storage setup
echo "🚀 Running terraform apply..."
terraform apply -auto-approve

# Step 5: Verify deployment
echo ""
echo "✅ Step 5: Verifying deployment..."

echo "📊 Checking pod status..."
kubectl get pods --all-namespaces | grep -E "(postgres|redis|minio|prometheus|grafana)" || true

echo "💾 Checking PVC status..."
kubectl get pvc --all-namespaces

echo ""
echo "🎉 ML Platform deployment completed successfully!"
echo ""
echo "🔗 To access services, use these port-forward commands:"
echo "  kubectl port-forward -n database svc/postgres 5432:5432"
echo "  kubectl port-forward -n cache svc/redis 6379:6379"
echo "  kubectl port-forward -n storage svc/minio 9001:9000"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo ""
echo "🌐 Service endpoints:"
echo "  Database: postgresql://admin:password@localhost:5432/metadata"
echo "  Cache: redis://localhost:6379"
echo "  Storage: http://localhost:9001 (minioadmin/minioadmin)"
echo "  Grafana: http://localhost:3000 (admin/admin)"
echo ""
echo "📚 Next: Follow APPLICATION-TRANSITION.md for app development"
echo ""
echo "💡 Usage: $0 [--clean-first]"
echo "   --clean-first: Delete existing cluster and clean terraform state before deployment"