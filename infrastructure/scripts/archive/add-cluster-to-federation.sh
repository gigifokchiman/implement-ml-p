#!/bin/bash
# Add a new cluster to the federation
# Usage: ./add-cluster-to-federation.sh <cluster-name> <nodeport>

set -e

CLUSTER_NAME=${1:-}
NODE_PORT=${2:-}

if [ -z "$CLUSTER_NAME" ] || [ -z "$NODE_PORT" ]; then
    echo "❌ Error: Cluster name and NodePort are required"
    echo "Usage: $0 <cluster-name> <nodeport>"
    echo "Example: $0 external-facing-app 30092"
    exit 1
fi

FEDERATION_CONFIG="/Users/chimanfok/workspaces/github/_data/implement-ml-p/monitoring/prometheus-federation.yml"

echo "🔗 Adding $CLUSTER_NAME to federation on port $NODE_PORT"

# Check if cluster already exists in config
if grep -q "cluster: '$CLUSTER_NAME'" "$FEDERATION_CONFIG"; then
    echo "⚠️  Cluster $CLUSTER_NAME already in federation config"
    exit 0
fi

# Add new cluster to federation config
cat >> "$FEDERATION_CONFIG" << EOF

  # Federation from $CLUSTER_NAME cluster
  - job_name: 'federate-$CLUSTER_NAME'
    scrape_interval: 30s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="prometheus"}'
        - '{__name__=~"job:.*"}'
        - '{__name__=~"node_.*"}'
        - '{__name__=~"kube_.*"}'
        - '{__name__=~"app_.*"}'   # Application-specific metrics
    static_configs:
      - targets: ['host.docker.internal:$NODE_PORT']
        labels:
          cluster: '$CLUSTER_NAME'
          environment: 'local'
EOF

echo "✅ Added $CLUSTER_NAME to federation config"

# Restart federation to pick up changes
echo "🔄 Restarting federation monitoring..."
docker compose -f docker-compose-federation.yml restart prometheus-federation

echo "⏳ Waiting for Prometheus to reload..."
sleep 5

# Test the new endpoint
echo "🧪 Testing new cluster federation..."
if curl -s "http://localhost:9092/api/v1/query?query=up{cluster=\"$CLUSTER_NAME\"}" | grep -q "$CLUSTER_NAME"; then
    echo "✅ $CLUSTER_NAME successfully added to federation!"
else
    echo "⚠️  $CLUSTER_NAME not yet visible in federation. It may take a minute."
fi

echo ""
echo "📊 View all clusters:"
echo "curl 'http://localhost:9092/api/v1/query?query=count by (cluster) (up)'"