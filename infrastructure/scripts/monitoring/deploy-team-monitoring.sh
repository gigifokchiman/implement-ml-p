#!/bin/bash
# Deploy team monitoring configuration (requires Prometheus CRDs from ArgoCD)
# This contains the monitoring logic that was removed from deploy-single-cluster-isolation.sh

set -e

echo "📊 Deploying Team Monitoring Configuration"
echo "========================================="

# Choose target cluster
CLUSTER_CONTEXT=${1:-kind-ml-platform-local}
echo "📋 Target cluster: $CLUSTER_CONTEXT"

# Switch to target cluster
kubectl config use-context $CLUSTER_CONTEXT

echo ""
echo "🔍 Checking Prometheus CRDs..."

# Check if Prometheus CRDs exist
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    echo "✅ Prometheus CRDs found, applying monitoring configuration..."
    
    echo ""
    echo "📊 Applying team monitoring manifests..."
    kubectl apply -f kubernetes/monitoring/namespace-monitoring.yaml
    kubectl apply -f kubernetes/monitoring/team-dashboards.yaml
    
    echo ""
    echo "✅ Team monitoring deployed successfully!"
    echo ""
    echo "📈 Monitoring Components:"
    echo "   • ServiceMonitors for ml-team, data-team, app-team"
    echo "   • PrometheusRules for resource quota alerts"
    echo "   • Team-specific dashboards and alerts"
    echo ""
    echo "🎯 Access monitoring:"
    echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "   Grafana: http://localhost:3000 (admin/prom-operator)"
    echo ""
    echo "📊 Verify monitoring deployment:"
    echo "   kubectl get servicemonitors --all-namespaces"
    echo "   kubectl get prometheusrules --all-namespaces"
    echo "   kubectl get pods -n monitoring"
    
else
    echo "⚠️  Prometheus CRDs not found. Skipping ServiceMonitor and PrometheusRule deployment."
    echo "💡 To enable full monitoring, deploy ArgoCD with Prometheus Operator first:"
    echo "   ./deploy-argocd.sh"
    echo "   ./setup-argocd-apps.sh"
    echo "   ./deploy-team-monitoring.sh"
    echo ""
    echo "🔧 Expected CRDs:"
    echo "   • servicemonitors.monitoring.coreos.com"
    echo "   • prometheusrules.monitoring.coreos.com"
    echo "   • podmonitors.monitoring.coreos.com"
    exit 1
fi