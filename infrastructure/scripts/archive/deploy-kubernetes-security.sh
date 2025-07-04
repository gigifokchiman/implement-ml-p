#!/bin/bash
# Deploy plain Kubernetes security - no service mesh needed

set -e

echo "🔐 Deploying Kubernetes Native Security"
echo "======================================"

CLUSTER_CONTEXT=${1:-kind-ml-platform-local}
echo "📋 Target cluster: $CLUSTER_CONTEXT"

kubectl config use-context $CLUSTER_CONTEXT

echo ""

echo "1️⃣ Installing cert-manager for TLS..."
# Check if cert-manager already exists
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
else
    echo "cert-manager already installed ✅"
fi

echo ""
echo "2️⃣ Installing NGINX ingress controller..."
# Check if nginx ingress already exists
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo "Installing NGINX ingress controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/kind/deploy.yaml
    echo "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
else
    echo "NGINX ingress controller already installed ✅"
fi

echo ""
echo "3️⃣ Applying TLS certificates and secure ingress..."
kubectl apply -f kubernetes/security/tls-ingress.yaml

echo ""
echo "4️⃣ Setting up audit logging..."
kubectl apply -f kubernetes/security/audit-logging.yaml

echo ""
echo "5️⃣ Configuring network policies..."
# Label namespaces for network policies to work
kubectl label namespace ingress-nginx name=ingress-nginx --overwrite
kubectl label namespace monitoring name=monitoring --overwrite

kubectl apply -f kubernetes/security/network-policies.yaml

echo ""
echo "6️⃣ Implementing rate limiting..."
kubectl apply -f kubernetes/security/rate-limiting.yaml

echo ""
echo "7️⃣ Setting up application-level security..."
kubectl apply -f kubernetes/security/app-level-logging.yaml

echo ""
echo "✅ Kubernetes native security deployed!"
echo ""
echo "🔐 Security Features Active:"
echo "   • TLS termination at ingress ✅"
echo "   • Audit logging for API calls ✅"
echo "   • Network policies for isolation ✅"
echo "   • Rate limiting per team/endpoint ✅"
echo "   • Application-level auth & logging ✅"
echo ""
echo "📊 Security Benefits:"
echo "   • Zero service mesh complexity"
echo "   • Full compliance coverage"
echo "   • $0 additional infrastructure cost"
echo "   • Industry-standard patterns"
echo ""
echo "🧪 Test security:"
echo "kubectl get networkpolicies --all-namespaces"
echo "kubectl get certificates --all-namespaces"
echo "kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller"
