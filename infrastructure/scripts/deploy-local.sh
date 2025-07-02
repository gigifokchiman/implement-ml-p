#!/bin/bash
# Comprehensive local ML Platform deployment script
# Handles both provider issues and deployment problems

set -e

echo "🚀 ML Platform Local Deployment Script"
echo "======================================"

# Get script directory and terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/local"

cd "$TERRAFORM_DIR"
echo "📍 Working in: $(pwd)"

# Step 1: Fix terraform-provider-kind issues
echo ""
echo "🔧 Step 1: Checking Terraform provider setup..."

# Check if we can run terraform init
if ! terraform init --upgrade 2>/dev/null; then
    echo "⚠️  Terraform init failed. Fixing provider checksum issues..."
    
    # Clean up existing terraform state
    rm -f .terraform.lock.hcl
    rm -rf .terraform
    
    # Check if custom provider needs to be built
    PROVIDER_DIR="$SCRIPT_DIR/../terraform-provider-kind"
    if [ -d "$PROVIDER_DIR" ]; then
        echo "🔨 Building custom terraform-provider-kind..."
        cd "$PROVIDER_DIR"
        
        go mod tidy
        go build -o terraform-provider-kind
        
        # Create plugin directory for current platform
        PLUGIN_DIR="$HOME/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/$(go env GOOS)_$(go env GOARCH)"
        mkdir -p "$PLUGIN_DIR"
        cp terraform-provider-kind "$PLUGIN_DIR/"
        
        echo "✅ Custom provider built and installed"
        cd "$TERRAFORM_DIR"
    fi
    
    # Try terraform init again
    echo "🔄 Re-initializing Terraform..."
    terraform init --upgrade
fi

echo "✅ Terraform provider setup complete"

# Step 2: Handle Kind cluster and storage setup
echo ""
echo "🐳 Step 2: Checking Kind cluster setup..."

# Check if Kind cluster exists
if ! kind get clusters | grep -q ml-platform-local; then
    echo "📦 Creating Kind cluster..."
    terraform apply -target=kind_cluster.default -auto-approve
else
    echo "✅ Kind cluster exists"
fi

# Set kubectl context
kubectl config use-context kind-ml-platform-local

# Step 3: Handle storage class
echo ""
echo "💾 Step 3: Setting up storage..."

if ! kubectl get storageclass standard 2>/dev/null; then
    echo "📂 Creating default storage class..."
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
else
    echo "✅ Storage class exists"
fi

# Step 4: Deploy the platform
echo ""
echo "🏗️  Step 4: Deploying ML Platform..."

# Check for any existing resource conflicts and handle PVCs
echo "🔍 Checking for pending PVCs..."
PENDING_PVCS=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -i pending || true)
if [ ! -z "$PENDING_PVCS" ]; then
    echo "⚠️  Found pending PVCs - will be resolved during deployment"
fi

# Run terraform apply with error handling
echo "🚀 Running terraform apply..."
if ! terraform apply -auto-approve -parallelism=3; then
    echo "⚠️  Terraform apply had issues. Checking for common problems..."
    
    # Handle PVC binding issues
    echo "🔄 Attempting to bind pending PVCs..."
    for namespace in database cache storage security-scanning; do
        if kubectl get namespace "$namespace" 2>/dev/null; then
            # Get PVCs in this namespace
            PVCS=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | grep Pending | awk '{print $1}' || true)
            for pvc in $PVCS; do
                echo "🔗 Binding PVC: $namespace/$pvc"
                kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pvc-binder-$pvc
  namespace: $namespace
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "10"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: $pvc
  restartPolicy: Never
EOF
                # Wait briefly for binding
                sleep 2
                kubectl delete pod "pvc-binder-$pvc" -n "$namespace" --ignore-not-found
            done
        fi
    done
    
    # Try terraform apply again
    echo "🔄 Retrying terraform apply..."
    terraform apply -auto-approve -parallelism=3
fi

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