#!/bin/bash
# Setup multi-cluster federation for ML and Data platforms

set -e

echo "🔗 Setting up Multi-Cluster Federation"
echo "=================================="

# Check if clusters exist
echo "📋 Checking clusters..."
if ! kind get clusters | grep -q "ml-platform-local"; then
    echo "❌ ml-platform-local cluster not found"
    exit 1
fi

if ! kind get clusters | grep -q "data-platform-local"; then
    echo "❌ data-platform-local cluster not found"
    exit 1
fi

echo "✅ Both clusters found"

# Setup NodePort for ML cluster Prometheus
echo ""
echo "🔧 Setting up ML cluster Prometheus NodePort..."
kubectl --context kind-ml-platform-local patch svc prometheus-server -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":9090,"nodePort":30090,"targetPort":9090,"protocol":"TCP"}]}}'

# Setup NodePort for Data cluster Prometheus  
echo "🔧 Setting up Data cluster Prometheus NodePort..."
kubectl --context kind-data-platform-local patch svc prometheus-server -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":9090,"nodePort":30091,"targetPort":9090,"protocol":"TCP"}]}}'

# Start federation monitoring
echo ""
echo "🚀 Starting central federation monitoring..."
docker-compose -f docker-compose-federation.yml up -d

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check federation targets
echo ""
echo "🎯 Checking federation targets..."
echo "Central Prometheus: http://localhost:9092"
echo "Central Grafana: http://localhost:3001 (admin/admin)"
echo ""
echo "ML Cluster Prometheus: http://localhost:30090"
echo "Data Cluster Prometheus: http://localhost:30091"

echo ""
echo "🧪 Testing federation connectivity..."

# Test ML cluster connectivity
if curl -s "http://localhost:30090/api/v1/label/__name__/values" > /dev/null; then
    echo "✅ ML cluster Prometheus accessible"
else
    echo "❌ ML cluster Prometheus not accessible"
fi

# Test Data cluster connectivity
if curl -s "http://localhost:30091/api/v1/label/__name__/values" > /dev/null; then
    echo "✅ Data cluster Prometheus accessible"
else
    echo "❌ Data cluster Prometheus not accessible"
fi

# Test federation Prometheus
sleep 5
if curl -s "http://localhost:9092/api/v1/targets" > /dev/null; then
    echo "✅ Federation Prometheus accessible"
else
    echo "❌ Federation Prometheus not accessible"
fi

echo ""
echo "🎉 Federation setup complete!"
echo ""
echo "📊 Access Points:"
echo "   • Central Monitoring: http://localhost:3001 (Grafana)"
echo "   • Federation Prometheus: http://localhost:9092"
echo "   • ML Cluster Direct: http://localhost:30090" 
echo "   • Data Cluster Direct: http://localhost:30091"
echo ""
echo "🔍 View federated metrics:"
echo "   curl 'http://localhost:9092/api/v1/query?query=up{cluster=~\".*\"}'"