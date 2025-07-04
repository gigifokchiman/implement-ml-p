#!/bin/bash
# Apply proper labeling to single cluster resources

set -e

echo "🏷️  Applying Proper Resource Labeling"
echo "===================================="

CLUSTER_CONTEXT=${1:-kind-ml-platform-local}
kubectl config use-context $CLUSTER_CONTEXT

echo ""
echo "1️⃣ Labeling nodes..."

# Get node names
CONTROL_PLANE=$(kubectl get nodes -o name | grep control-plane | head -1)
WORKER_NODES=$(kubectl get nodes -o name | grep -v control-plane)

# Label control plane
if [ ! -z "$CONTROL_PLANE" ]; then
    echo "Labeling control plane: $CONTROL_PLANE"
    kubectl label $CONTROL_PLANE workload-type=mixed --overwrite
    kubectl label $CONTROL_PLANE hardware=general-compute --overwrite
    kubectl label $CONTROL_PLANE environment=production --overwrite
    kubectl label $CONTROL_PLANE cluster-name=ml-platform-local --overwrite
    kubectl label $CONTROL_PLANE cost-center=platform --overwrite
fi

# Label worker nodes (simulate different node types)
node_count=0
for node in $WORKER_NODES; do
    case $node_count in
        0)
            echo "Labeling worker as ML node: $node"
            kubectl label $node workload-type=ml-compute --overwrite
            kubectl label $node hardware=gpu-enabled --overwrite
            kubectl label $node team=ml-engineering --overwrite
            kubectl label $node cost-center=ml --overwrite
            ;;
        1)
            echo "Labeling worker as Data node: $node"
            kubectl label $node workload-type=data-processing --overwrite
            kubectl label $node hardware=high-memory --overwrite
            kubectl label $node team=data-engineering --overwrite
            kubectl label $node cost-center=data --overwrite
            ;;
        *)
            echo "Labeling worker as App node: $node"
            kubectl label $node workload-type=application --overwrite
            kubectl label $node hardware=general-compute --overwrite
            kubectl label $node team=application-engineering --overwrite
            kubectl label $node cost-center=app --overwrite
            ;;
    esac
    
    # Common labels for all workers
    kubectl label $node environment=production --overwrite
    kubectl label $node cluster-name=ml-platform-local --overwrite
    
    ((node_count++))
done

echo ""
echo "2️⃣ Updating namespace labels..."

# Update ML namespace
kubectl label namespace ml-team workload-type=ml-compute --overwrite
kubectl label namespace ml-team gpu-enabled=true --overwrite
kubectl label namespace ml-team data-classification=internal --overwrite
kubectl label namespace ml-team backup-policy=daily --overwrite
kubectl label namespace ml-team monitoring-tier=premium --overwrite

# Update Data namespace  
kubectl label namespace data-team workload-type=data-processing --overwrite
kubectl label namespace data-team storage-intensive=true --overwrite
kubectl label namespace data-team data-classification=confidential --overwrite
kubectl label namespace data-team backup-policy=hourly --overwrite
kubectl label namespace data-team monitoring-tier=premium --overwrite

# Update App namespace
kubectl label namespace app-team workload-type=web-service --overwrite
kubectl label namespace app-team external-facing=true --overwrite
kubectl label namespace app-team data-classification=public --overwrite
kubectl label namespace app-team backup-policy=daily --overwrite
kubectl label namespace app-team monitoring-tier=standard --overwrite

echo ""
echo "3️⃣ Creating node selectors for team workloads..."

# Create node affinity examples
cat > /tmp/ml-nodeaffinity.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference-example
  namespace: ml-team
  labels:
    team: ml-engineering
    app.kubernetes.io/name: ml-inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ml-inference
  template:
    metadata:
      labels:
        app: ml-inference
        team: ml-engineering
        workload-type: ml-inference
        cost-center: ml
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: workload-type
                operator: In
                values: ["ml-compute"]
          - weight: 80
            preference:
              matchExpressions:
              - key: hardware
                operator: In
                values: ["gpu-enabled"]
      containers:
      - name: inference
        image: nginx  # placeholder
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
EOF

kubectl apply -f /tmp/ml-nodeaffinity.yaml

echo ""
echo "4️⃣ Installing labeling policies..."
kubectl apply -f kubernetes/labeling/

echo ""
echo "✅ Resource labeling applied!"
echo ""
echo "📊 Node labels:"
kubectl get nodes --show-labels | cut -d' ' -f1,6- | column -t
echo ""
echo "📊 Namespace labels:"
kubectl get namespaces --show-labels | grep -E "(ml-team|data-team|app-team)"
echo ""
echo "🔍 Verify with:"
echo "kubectl get nodes -l workload-type=ml-compute"
echo "kubectl get pods -l team=ml-engineering --all-namespaces"