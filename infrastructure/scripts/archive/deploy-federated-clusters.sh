#!/bin/bash
# Multi-Cluster Federation with Centralized Monitoring
# Creates: ML cluster + Data cluster + Shared monitoring cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying Multi-Cluster Federation Architecture"
echo "================================================="
echo ""
echo "This creates:"
echo "✅ ML Platform Cluster (for ML workloads)"
echo "✅ Data Platform Cluster (for data processing)"  
echo "✅ Shared Monitoring Cluster (centralized observability)"
echo ""

# Step 1: Create KIND cluster configurations
echo "📝 Creating cluster configurations..."

cat > /tmp/ml-cluster-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ml-platform
networking:
  apiServerPort: 6443
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080  # ML applications
    hostPort: 8100
  - containerPort: 30090  # Prometheus
    hostPort: 9090
- role: worker
- role: worker
EOF

cat > /tmp/data-cluster-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: data-platform
networking:
  apiServerPort: 6444
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30081  # Data applications
    hostPort: 8110
  - containerPort: 30091  # Prometheus
    hostPort: 9091
- role: worker
- role: worker
EOF

cat > /tmp/monitoring-cluster-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: shared-monitoring
networking:
  apiServerPort: 6445
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30082  # Grafana
    hostPort: 3000
  - containerPort: 30092  # Central Prometheus
    hostPort: 9092
- role: worker
EOF

# Step 2: Create the clusters
echo "🔧 Creating KIND clusters..."
kind create cluster --config /tmp/ml-cluster-config.yaml
kind create cluster --config /tmp/data-cluster-config.yaml  
kind create cluster --config /tmp/monitoring-cluster-config.yaml

# Step 3: Add Helm repos
echo "📦 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Step 4: Deploy Prometheus agents on each cluster
echo "⚓ Deploying Prometheus agents..."

# ML Cluster Prometheus
kubectl config use-context kind-ml-platform
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --wait

# Data Cluster Prometheus  
kubectl config use-context kind-data-platform
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30091 \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --wait

# Step 5: Deploy applications on each cluster
echo "🚀 Deploying applications..."

# Deploy ML Platform
kubectl config use-context kind-ml-platform
kubectl create namespace ml-platform
helm install ml-stack ../helm/charts/platform-template \
  --namespace ml-platform \
  --set app.name=ml-platform \
  --set services.api.enabled=true \
  --set database.enabled=true \
  --set cache.enabled=true \
  --set storage.enabled=true \
  --wait

# Deploy Data Platform
kubectl config use-context kind-data-platform
kubectl create namespace data-platform
helm install data-stack ../helm/charts/platform-template \
  --namespace data-platform \
  --set app.name=data-platform \
  --set services.api.enabled=true \
  --set database.enabled=true \
  --set cache.enabled=true \
  --set storage.enabled=true \
  --wait

# Step 6: Create federation configuration
echo "🔗 Setting up Prometheus federation..."

cat > /tmp/federation-values.yaml <<EOF
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: 'federate-ml'
      scrape_interval: 30s
      honor_labels: true
      metrics_path: '/federate'
      params:
        'match[]':
          - '{job="prometheus"}'
          - '{__name__=~"job:.*"}'
          - '{__name__=~"node_.*"}'
          - '{__name__=~"kube_.*"}'
          - '{__name__=~"ml_.*"}'
      static_configs:
      - targets:
        - 'host.docker.internal:9090'
        labels:
          cluster: 'ml-platform'
    
    - job_name: 'federate-data'
      scrape_interval: 30s
      honor_labels: true
      metrics_path: '/federate'
      params:
        'match[]':
          - '{job="prometheus"}'
          - '{__name__=~"job:.*"}'
          - '{__name__=~"node_.*"}'
          - '{__name__=~"kube_.*"}'
          - '{__name__=~"data_.*"}'
      static_configs:
      - targets:
        - 'host.docker.internal:9091'
        labels:
          cluster: 'data-platform'

grafana:
  service:
    type: NodePort
    nodePort: 30082
  adminPassword: admin123
  
alertmanager:
  enabled: true
  service:
    type: NodePort
    nodePort: 30093
EOF

# Step 7: Deploy centralized monitoring
echo "📊 Deploying centralized monitoring..."
kubectl config use-context kind-shared-monitoring
kubectl create namespace monitoring
helm install central-monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /tmp/federation-values.yaml \
  --wait

# Step 8: Create unified dashboards
echo "📈 Setting up dashboards..."

cat > /tmp/multi-cluster-dashboard.json <<EOF
{
  "dashboard": {
    "title": "Multi-Cluster Overview",
    "panels": [
      {
        "title": "Cluster Resource Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (cluster) (kube_node_status_allocatable{resource=\"cpu\"})",
            "legendFormat": "{{cluster}} CPU"
          },
          {
            "expr": "sum by (cluster) (kube_node_status_allocatable{resource=\"memory\"})",
            "legendFormat": "{{cluster}} Memory"
          }
        ]
      },
      {
        "title": "Pod Count by Cluster",
        "type": "graph",
        "targets": [
          {
            "expr": "sum by (cluster) (kube_pod_info)",
            "legendFormat": "{{cluster}}"
          }
        ]
      }
    ]
  }
}
EOF

# Step 9: Cleanup temp files
rm -f /tmp/*-cluster-config.yaml /tmp/federation-values.yaml /tmp/multi-cluster-dashboard.json

echo ""
echo "✅ Multi-Cluster Federation deployed successfully!"
echo ""
echo "🎯 Access Points:"
echo "   ML Platform:      http://localhost:8100"
echo "   Data Platform:    http://localhost:8110"
echo "   Central Grafana:  http://localhost:3000 (admin/admin123)"
echo "   ML Prometheus:    http://localhost:9090"
echo "   Data Prometheus:  http://localhost:9091"
echo "   Central Prometheus: http://localhost:9092"
echo ""
echo "🔍 Cluster Status:"
kind get clusters
echo ""
echo "📊 Monitoring Status:"
echo "Switch contexts to check each cluster:"
echo "   kubectl config use-context kind-ml-platform"
echo "   kubectl config use-context kind-data-platform"
echo "   kubectl config use-context kind-shared-monitoring"
echo ""
echo "🧹 Cleanup command:"
echo "   kind delete clusters ml-platform data-platform shared-monitoring"