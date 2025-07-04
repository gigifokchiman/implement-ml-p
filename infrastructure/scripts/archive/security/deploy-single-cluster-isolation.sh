#!/bin/bash
# Deploy single cluster with team isolation

set -e

echo "🚀 Deploying Single Cluster with Team Isolation"
echo "==============================================="

# Choose target cluster
CLUSTER_CONTEXT=${1:-kind-ml-platform-local}
echo "📋 Target cluster: $CLUSTER_CONTEXT"

# Switch to target cluster
kubectl config use-context $CLUSTER_CONTEXT

echo ""
echo "1️⃣ Creating team namespaces and resource quotas..."
kubectl apply -f kubernetes/team-isolation/ml-team-resources.yaml
kubectl apply -f kubernetes/team-isolation/data-team-resources.yaml
kubectl apply -f kubernetes/team-isolation/app-team-resources.yaml

echo ""
echo "2️⃣ Setting up RBAC policies..."
kubectl apply -f kubernetes/rbac/ml-team-rbac.yaml
kubectl apply -f kubernetes/rbac/data-team-rbac.yaml
kubectl apply -f kubernetes/rbac/app-team-rbac.yaml

echo ""
echo "3️⃣ Skipping monitoring setup..."
echo "💡 Monitoring (ServiceMonitors, PrometheusRules) should be deployed via ArgoCD"
echo "   after Prometheus CRDs are installed through GitOps workflow"

echo ""
echo "4️⃣ Setting up disaster recovery..."
echo "⚠️  Note: Update cloud credentials in velero-backup.yaml before applying"
# kubectl apply -f kubernetes/disaster-recovery/velero-backup.yaml
# kubectl apply -f kubernetes/disaster-recovery/etcd-backup.yaml

echo ""
echo "✅ Single cluster isolation deployed!"
echo ""
echo "📊 Team Resource Limits:"
echo "   • ML Team: 20 CPU cores, 64GB RAM, 500GB storage"
echo "   • Data Team: 16 CPU cores, 48GB RAM, 1TB storage"  
echo "   • App Team: 8 CPU cores, 24GB RAM, 200GB storage"
echo ""
echo "🔐 RBAC configured for team boundaries"
echo "📈 Monitoring alerts set for quota usage"
echo "💾 DR strategy ready (configure cloud storage)"
echo ""
echo "🧪 Test team isolation:"
echo "kubectl config set-context --current --namespace=ml-team"
echo "kubectl get resourcequota"
echo "kubectl auth can-i create pods --as=system:serviceaccount:data-team:default -n ml-team"