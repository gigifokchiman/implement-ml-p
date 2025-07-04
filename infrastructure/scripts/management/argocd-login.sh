#!/bin/bash
# ArgoCD Login Helper Script

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
ARGOCD_PORT=8080
ARGOCD_NAMESPACE="argocd"
TF_DIR="terraform/environments/local"
ARGOCD_URL="https://localhost:${ARGOCD_PORT}"  # Use HTTPS with TLS

echo -e "${BLUE}🔐 ArgoCD Login Helper${NC}"
echo "======================"

# Step 1: Check if port-forward is running
if ! pgrep -f "kubectl port-forward.*argocd" > /dev/null; then
    echo -e "${YELLOW}⚠️  ArgoCD port-forward not detected${NC}"
    echo "Starting port-forward in background..."
    
    # Get ArgoCD server pod name
    POD_NAME=$(kubectl get pod -n ${ARGOCD_NAMESPACE} -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$POD_NAME" ]; then
        kubectl port-forward pod/$POD_NAME -n ${ARGOCD_NAMESPACE} ${ARGOCD_PORT}:8080 > /dev/null 2>&1 &
        sleep 3
        echo -e "${GREEN}✅ Port-forward started to pod $POD_NAME${NC}"
    else
        echo -e "${RED}❌ Could not find ArgoCD server pod${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Port-forward already running${NC}"
fi

# Step 2: Get password from secure secret store
echo -e "\n${BLUE}📋 Retrieving ArgoCD password securely...${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GET_SECRET_SCRIPT="$SCRIPT_DIR/get-secret.sh"

PASSWORD=""

# Try secure secret store first
if [ -f "$GET_SECRET_SCRIPT" ]; then
    PASSWORD=$("$GET_SECRET_SCRIPT" argocd_admin_password 2>/dev/null || echo "")
    if [ -n "$PASSWORD" ]; then
        echo -e "${GREEN}✅ Password retrieved from secure secret store${NC}"
    fi
fi

# Fallback to Kubernetes secret
if [ -z "$PASSWORD" ]; then
    PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
    if [ -n "$PASSWORD" ]; then
        echo -e "${GREEN}✅ Password retrieved from Kubernetes${NC}"
    fi
fi

# Check if password was found
if [ -z "$PASSWORD" ]; then
    echo -e "${RED}❌ Could not retrieve ArgoCD password${NC}"
    echo "Please check your ArgoCD installation"
    exit 1
fi

# Step 3: Login to ArgoCD
echo -e "\n${BLUE}🔐 Logging into ArgoCD...${NC}"
argocd login localhost:${ARGOCD_PORT} \
    --username admin \
    --password "$PASSWORD" \
    --insecure

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Successfully logged into ArgoCD!${NC}"
    echo -e "\n${BLUE}📋 Quick Commands:${NC}"
    echo "  argocd app list              # List all applications"
    echo "  argocd app sync <app-name>   # Sync an application"
    echo "  argocd app get <app-name>    # Get app details"
    echo ""
    echo -e "${YELLOW}💡 Tip:${NC} Access the UI at https://localhost:${ARGOCD_PORT}"
    echo "  Username: admin"
    echo "  Password: $PASSWORD"
else
    echo -e "\n${RED}❌ Failed to login to ArgoCD${NC}"
    echo "Please check:"
    echo "  1. ArgoCD is running: kubectl get pods -n argocd"
    echo "  2. Port-forward is active: ps aux | grep port-forward"
    exit 1
fi