#!/bin/bash
# Deploy ArgoCD with Prometheus monitoring stack
# This sets up GitOps workflow and installs Prometheus CRDs

set -e

echo "🚀 Deploying ArgoCD with Monitoring Stack"
echo "========================================="

# Choose target cluster
CLUSTER_CONTEXT=${1:-kind-data-platform-local}
echo "📋 Target cluster: $CLUSTER_CONTEXT"

# Switch to target cluster
kubectl config use-context $CLUSTER_CONTEXT

echo ""
echo "1️⃣ Installing ArgoCD..."

# Create ArgoCD namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s

echo ""
echo "2️⃣ Installing Prometheus Operator (for CRDs)..."

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes CRDs)
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --wait --timeout=10m

echo "⏳ Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=prometheus --timeout=300s

echo ""
echo "3️⃣ Configuring ArgoCD access..."

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "✅ ArgoCD and Monitoring Stack deployed successfully!"
echo ""
echo "🎯 Access ArgoCD:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   URL: https://localhost:8080"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "📊 Access Grafana:"
echo "   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "   URL: http://localhost:3000"
echo "   Username: admin"
echo "   Password: prom-operator"
echo ""
echo "🔧 Verify CRDs installed:"
echo "   kubectl get crd | grep monitoring.coreos.com"
echo ""
echo "🎯 Next steps:"
echo "   1. Access ArgoCD UI and configure repositories"
echo "   2. Deploy applications via GitOps workflow"
echo "   3. Run: ./deploy-team-monitoring.sh"
echo ""
echo "📋 ArgoCD Resources:"
echo "   Namespace: argocd"
echo "   Service: argocd-server"
echo "   Port: 443 (HTTPS)"
echo ""
echo "📋 Monitoring Resources:"
echo "   Namespace: monitoring"
echo "   Prometheus: prometheus-kube-prometheus-prometheus"
echo "   Grafana: prometheus-grafana"
