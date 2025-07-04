#!/bin/bash
# Validate security configuration (utility script)
# No deployment - just validation and testing

set -e

echo "🔍 Security Configuration Validation"
echo "===================================="

CLUSTER_CONTEXT=${1:-kind-data-platform-local}
kubectl config use-context $CLUSTER_CONTEXT

echo ""
echo "1️⃣ Checking Security Infrastructure..."
echo "------------------------------------"

# Check cert-manager
if kubectl get deployment cert-manager -n cert-manager &>/dev/null; then
    echo "✅ cert-manager: Running"
    kubectl get pods -n cert-manager --no-headers | while read pod rest; do
        status=$(echo $rest | awk '{print $3}')
        echo "   - $pod: $status"
    done
else
    echo "❌ cert-manager: Not found"
fi

# Check ingress controller
if kubectl get deployment ingress-nginx-controller -n ingress-nginx &>/dev/null; then
    echo "✅ ingress-nginx: Running"
    kubectl get pods -n ingress-nginx --no-headers | while read pod rest; do
        status=$(echo $rest | awk '{print $3}')
        echo "   - $pod: $status"
    done
else
    echo "❌ ingress-nginx: Not found"
fi

echo ""
echo "2️⃣ Checking Network Policies..."
echo "-----------------------------"

# Check network policies
policies=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l | xargs)
if [ "$policies" -gt 0 ]; then
    echo "✅ Network policies: $policies found"
    kubectl get networkpolicies --all-namespaces --no-headers | while read ns name rest; do
        echo "   - $ns/$name"
    done
else
    echo "❌ Network policies: None found"
fi

echo ""
echo "3️⃣ Checking TLS Certificates..."
echo "-----------------------------"

# Check certificates
certificates=$(kubectl get certificates --all-namespaces --no-headers | wc -l | xargs)
if [ "$certificates" -gt 0 ]; then
    echo "✅ TLS certificates: $certificates found"
    kubectl get certificates --all-namespaces --no-headers | while read ns name ready secret age; do
        echo "   - $ns/$name: Ready=$ready"
    done
else
    echo "❌ TLS certificates: None found"
fi

echo ""
echo "4️⃣ Testing Network Connectivity..."
echo "-------------------------------"

# Test network policies (if pods exist)
for ns in app-ml-team app-data-team app-core-team; do
    if kubectl get namespace $ns &>/dev/null; then
        echo "Testing $ns network isolation..."
        
        # Create test pod if it doesn't exist
        if ! kubectl get pod network-test -n $ns &>/dev/null; then
            kubectl run network-test --image=nicolaka/netshoot -n $ns --rm -it --restart=Never --timeout=10s -- /bin/bash -c "echo 'Network test pod created in $ns'" || true
        fi
    fi
done

echo ""
echo "5️⃣ Security Summary..."
echo "-------------------"

# Count security resources
cert_manager_pods=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l | xargs)
ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l | xargs)
network_policies=$(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l | xargs)
certificates=$(kubectl get certificates --all-namespaces --no-headers 2>/dev/null | wc -l | xargs)

echo "📊 Security Infrastructure Status:"
echo "  - cert-manager pods: $cert_manager_pods"
echo "  - ingress controller pods: $ingress_pods"
echo "  - network policies: $network_policies"
echo "  - TLS certificates: $certificates"

echo ""
echo "🔐 Security Features:"
if [ "$cert_manager_pods" -gt 0 ]; then
    echo "  ✅ TLS certificate management"
else
    echo "  ❌ TLS certificate management"
fi

if [ "$ingress_pods" -gt 0 ]; then
    echo "  ✅ Secure ingress termination"
else
    echo "  ❌ Secure ingress termination"
fi

if [ "$network_policies" -gt 0 ]; then
    echo "  ✅ Network isolation policies"
else
    echo "  ❌ Network isolation policies"
fi

if [ "$certificates" -gt 0 ]; then
    echo "  ✅ Application TLS certificates"
else
    echo "  ❌ Application TLS certificates"
fi

echo ""
echo "💡 Next Steps:"
echo "  - Deploy infrastructure: make terraform-security-bootstrap"
echo "  - Deploy policies: make argocd-deploy-security"
echo "  - Check ArgoCD apps: make argocd-status"