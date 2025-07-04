#!/bin/bash
# Create external-facing-app cluster with KIND

set -e

echo "🚀 Creating external-facing-app cluster"

# Create KIND config
cat <<EOF > external-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: external-facing-app-local
networking:
  apiServerPort: 6446
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8300
  - containerPort: 443
    hostPort: 8643
  - containerPort: 30092
    hostPort: 30092
    protocol: TCP
- role: worker
EOF

# Create the cluster
kind create cluster --config external-cluster-config.yaml

echo "✅ Cluster created"

# Install Prometheus with NodePort 30092
echo "📦 Installing Prometheus..."
kubectl config use-context kind-external-facing-app-local

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30092 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout=300s

echo "✅ Prometheus installed on port 30092"

# Add to federation
echo ""
echo "🔗 Adding to federation..."
./add-cluster-to-federation.sh external-facing-app 30092

echo ""
echo "🎉 External-facing-app cluster ready!"
echo "   Direct access: http://localhost:30092"
echo "   Via federation: http://localhost:9092"