#!/bin/bash
# Clean up test multi-cluster setup for single cluster approach

echo "🧹 Cleaning up test multi-cluster components..."

# Stop federation monitoring
echo "Stopping federation containers..."
docker compose -f docker-compose-federation.yml down -v 2>/dev/null || true

# Delete test clusters (keep ml-platform-local for single cluster use)
echo "Deleting test clusters..."
kind delete cluster --name data-platform-local 2>/dev/null || true
kind delete cluster --name external-facing-app-local 2>/dev/null || true

# Clean up federation files
echo "Cleaning up federation test files..."
rm -f external-cluster-config.yaml 2>/dev/null || true
rm -f create-external-cluster.sh 2>/dev/null || true
rm -f add-cluster-to-federation.sh 2>/dev/null || true
rm -f setup-federation.sh 2>/dev/null || true
rm -f setup-prometheus-clusters.sh 2>/dev/null || true
rm -f docker-compose-federation.yml 2>/dev/null || true
rm -rf monitoring/prometheus-federation.yml 2>/dev/null || true

echo "✅ Cleanup complete!"
echo ""
echo "📋 Current state:"
kind get clusters
echo ""
echo "🎯 Ready for single cluster approach with ml-platform-local"
echo "Run: ./deploy-single-cluster-isolation.sh"