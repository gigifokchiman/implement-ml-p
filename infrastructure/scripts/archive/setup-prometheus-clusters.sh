#!/bin/bash
# Install Prometheus on both ML and Data clusters

set -e

echo "🚀 Installing Prometheus on ML and Data clusters"
echo "================================================"

# Add Prometheus Helm repo
echo "📦 Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install on ML cluster
echo ""
echo "🔧 Installing Prometheus on ML cluster..."
kubectl config use-context kind-ml-platform-local

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout=300s

echo "✅ Prometheus installed on ML cluster"

# Install on Data cluster  
echo ""
echo "🔧 Installing Prometheus on Data cluster..."
kubectl config use-context kind-data-platform-local

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30091 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout=300s

echo "✅ Prometheus installed on Data cluster"

echo ""
echo "📊 Cluster Status:"
echo "ML cluster: http://localhost:30090"
echo "Data cluster: http://localhost:30091"

echo ""
echo "🧪 Testing connectivity..."
sleep 10

if curl -s "http://localhost:30090/api/v1/label/__name__/values" > /dev/null; then
    echo "✅ ML cluster Prometheus ready"
else
    echo "⏳ ML cluster Prometheus starting up..."
fi

if curl -s "http://localhost:30091/api/v1/label/__name__/values" > /dev/null; then
    echo "✅ Data cluster Prometheus ready"
else
    echo "⏳ Data cluster Prometheus starting up..."
fi

echo ""
echo "🎉 Setup complete! Ready for federation."