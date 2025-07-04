#!/bin/bash
# Comprehensive local ML Platform deployment script
# Handles both provider issues and deployment problems with storage fixes

set -e

echo "🚀 ML Platform Local Deployment Script"
echo "======================================"

# Function to clean up existing resources
cleanup_existing() {
    echo "🧹 Cleaning up existing resources..."

    # Use Makefile target for cleanup (ensure we're in infrastructure root)
    cd "$INFRASTRUCTURE_ROOT"
    make destroy-local || {
        echo "⚠️  Makefile destroy failed, falling back to manual cluster cleanup..."
        # If make destroy fails, try to delete the Kind cluster directly
        if kind get clusters | grep -q ml-platform-local; then
            echo "🗑️  Deleting Kind cluster manually..."
            kind delete cluster --name ml-platform-local
        fi
    }

    # Clean up using Makefile
    make cleanup-local

    echo "✅ Cleanup complete"
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

# Get script directory and change to infrastructure root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # TODO: refactor
INFRASTRUCTURE_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"     # TODO: refactor
cd "$INFRASTRUCTURE_ROOT"

echo "📍 Working in: $INFRASTRUCTURE_ROOT"

# Run cleanup if requested
if [ "$CLEANUP_FIRST" = true ]; then
    cleanup_existing
fi

# Step 1: Initialize Terraform using Makefile
echo ""
echo "🔧 Step 1: Setting up Terraform..."
make init-local

echo "✅ Terraform provider setup complete"

# Step 2: Create Kind cluster first using Makefile
echo ""
echo "🐳 Step 2: Creating Kind cluster..."
make apply-cluster-local

# Set kubectl context using Makefile
echo "🔧 Configuring kubectl context..."
make setup-kubectl

# Step 3: Setup storage provisioner using Makefile
echo ""
echo "💾 Step 3: Setting up storage provisioner..."
make setup-storage-local

# Step 4: Deploy the platform using Makefile
echo ""
echo "🏗️  Step 4: Deploying ML Platform..."
make apply-local

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
