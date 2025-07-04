#!/bin/bash
# View federation status

echo "🔍 Federation Status Report"
echo "=========================="
echo ""

# List clusters
echo "📋 Active KIND clusters:"
kind get clusters | sed 's/^/   • /'
echo ""

# Check federation targets
echo "🎯 Federation targets:"
curl -s "http://localhost:9092/api/v1/targets" | \
  grep -o '"job":"federate[^"]*".*?"health":"[^"]*"' | \
  sed 's/.*job":"federate-\([^"]*\)".*health":"\([^"]*\)".*/   • \1: \2/'
echo ""

# Show metrics per cluster
echo "📊 Metrics per cluster:"
curl -s 'http://localhost:9092/api/v1/query?query=count by (cluster) (up)' | \
  grep -o '"cluster":"[^"]*","value":\[[^,]*,[^]]*' | \
  sed 's/"cluster":"\([^"]*\)","value":\[[^,]*,"\([^"]*\).*/   • \1: \2 targets/'
echo ""

# Show sample metrics
echo "📈 Sample metrics available:"
echo "   • Node metrics: node_cpu_seconds_total, node_memory_MemAvailable_bytes"
echo "   • Kubernetes metrics: kube_pod_info, kube_deployment_status_replicas"
echo "   • Custom metrics: ml_*, data_*, app_*"
echo ""

echo "🌐 Access points:"
echo "   • Central Grafana: http://localhost:3001 (admin/admin)"
echo "   • Federation Prometheus: http://localhost:9092"
echo "   • ML Cluster: http://localhost:30090"
echo "   • Data Cluster: http://localhost:30091"
echo "   • External App: http://localhost:30092"