#!/bin/bash
# Secure Secret Retrieval Script
# Fetches secrets from the Kubernetes secret store without exposing them in command line

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SECRET_NAMESPACE="secret-store"
SECRET_NAME="platform-secrets"

# Usage function
usage() {
    echo -e "${BLUE}🔐 Secure Secret Retrieval${NC}"
    echo "================================"
    echo ""
    echo "Usage: $0 <secret-key>"
    echo ""
    echo -e "${YELLOW}Available secrets:${NC}"
    echo "  argocd_admin_password    - ArgoCD admin password"
    echo "  grafana_admin_password   - Grafana admin password"
    echo "  postgres_admin_password  - PostgreSQL admin password"
    echo "  redis_password          - Redis password"
    echo "  minio_access_key        - MinIO access key"
    echo "  minio_secret_key        - MinIO secret key"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 argocd_admin_password"
    echo "  $0 grafana_admin_password"
    echo ""
    echo -e "${YELLOW}Security Features:${NC}"
    echo "  ✅ No plaintext in command line"
    echo "  ✅ No exposure in shell history"
    echo "  ✅ No exposure in process list"
    echo "  ✅ Output can be piped securely"
}

# Check if secret key is provided
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

SECRET_KEY="$1"

# Validate secret key
case "$SECRET_KEY" in
    argocd_admin_password|grafana_admin_password|postgres_admin_password|redis_password|minio_access_key|minio_secret_key)
        # Valid secret key
        ;;
    *)
        echo -e "${RED}❌ Invalid secret key: $SECRET_KEY${NC}"
        echo ""
        usage
        exit 1
        ;;
esac

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" &> /dev/null; then
    echo -e "${RED}❌ Secret '$SECRET_NAME' not found in namespace '$SECRET_NAMESPACE'${NC}"
    echo "Make sure you have deployed the secret store:"
    echo "  terraform apply"
    exit 1
fi

# Retrieve secret
SECRET_VALUE=$(kubectl get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" -o jsonpath="{.data.$SECRET_KEY}" 2>/dev/null | base64 -d 2>/dev/null)

if [ -z "$SECRET_VALUE" ]; then
    echo -e "${RED}❌ Secret key '$SECRET_KEY' not found in secret '$SECRET_NAME'${NC}"
    echo ""
    echo "Available keys in secret:"
    kubectl get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "  (Unable to list keys)"
    exit 1
fi

# Output the secret value (can be piped)
echo "$SECRET_VALUE"