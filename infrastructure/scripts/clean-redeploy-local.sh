#!/bin/bash
# Clean redeployment script for local environment

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧹 ML Platform Clean Redeployment${NC}"
echo "================================="
echo ""

# Step 1: Clean up everything
echo -e "${YELLOW}Step 1: Cleaning up existing deployment...${NC}"
cd /Users/chimanfok/workspaces/github/_data/implement-ml-p/infrastructure

# Clean metrics-server specifically
echo "  - Removing metrics-server..."
helm uninstall metrics-server -n kube-system --ignore-not-found || true
kubectl delete deployment,service,serviceaccount,rolebinding,clusterrole,clusterrolebinding -l app.kubernetes.io/name=metrics-server -A --ignore-not-found || true
kubectl delete deployment,service,serviceaccount,rolebinding,clusterrole,clusterrolebinding metrics-server -n kube-system --ignore-not-found || true
kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found || true

# Clean Terraform
echo "  - Cleaning Terraform state..."
make clean-tf-local || true

# Clean Helm releases
echo "  - Cleaning Helm releases..."
make clean-helm-local || true

echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

# Step 2: Destroy Kind cluster
echo -e "${YELLOW}Step 2: Destroying Kind cluster...${NC}"
make local-down || true
echo -e "${GREEN}✅ Kind cluster destroyed${NC}"
echo ""

# Step 3: Create fresh Kind cluster
echo -e "${YELLOW}Step 3: Creating fresh Kind cluster...${NC}"
make local-cluster-up
echo -e "${GREEN}✅ Kind cluster created${NC}"
echo ""

# Step 4: Deploy platform
echo -e "${YELLOW}Step 4: Deploying ML platform...${NC}"
make init-tf-local
make apply-tf-local
echo -e "${GREEN}✅ Platform deployed${NC}"
echo ""

# Step 5: Deploy monitoring separately
echo -e "${YELLOW}Step 5: Deploying monitoring stack...${NC}"
make deploy-monitoring-tf-local
echo -e "${GREEN}✅ Monitoring deployed${NC}"
echo ""

# Step 6: Verify deployment
echo -e "${BLUE}📊 Verifying deployment...${NC}"
echo ""
echo "Cluster nodes:"
kubectl get nodes
echo ""
echo "All pods:"
kubectl get pods --all-namespaces
echo ""
echo "Testing metrics (may take 30-60 seconds to be ready):"
sleep 30
kubectl top nodes || echo "Metrics API still initializing..."
echo ""

echo -e "${GREEN}🎉 Clean redeployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  - Wait 1-2 minutes for metrics-server to fully initialize"
echo "  - Run: kubectl top nodes"
echo "  - Run: kubectl top pods --all-namespaces"