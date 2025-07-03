#!/bin/bash
# Long-term fix for Kind storage issues
set -e

echo "🔧 Fixing Kind storage provisioner..."

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

echo "✅ Storage provisioner fixed!"