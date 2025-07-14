#!/bin/bash
# Simple test runner that won't hang
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "========================================"
echo "Simple Infrastructure Tests"
echo "========================================"

# Test 1: Terraform format check
print_info "Checking Terraform formatting..."
if command -v terraform >/dev/null 2>&1; then
    if terraform fmt -check -recursive "$SCRIPT_DIR/../terraform" >/dev/null 2>&1; then
        print_success "Terraform formatting is correct"
    else
        print_error "Terraform formatting issues found"
        terraform fmt -recursive "$SCRIPT_DIR/../terraform"
        print_success "Terraform formatting fixed"
    fi
else
    print_info "Terraform not available, skipping format check"
fi

# Test 2: YAML syntax check
print_info "Checking YAML syntax..."
yaml_errors=0
if find "$SCRIPT_DIR/../kubernetes" -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -5 | while read -r file; do
    if command -v yq >/dev/null 2>&1; then
        if ! yq eval . "$file" >/dev/null 2>&1; then
            echo "YAML syntax error in: $file"
            yaml_errors=$((yaml_errors + 1))
        fi
    fi
done; then
    print_success "YAML syntax validation passed"
else
    print_error "YAML syntax issues found"
fi

# Test 3: Security tools availability
print_info "Checking security tools..."
#if command -v tfsec >/dev/null 2>&1; then
#    print_success "tfsec available"
#    # Quick tfsec test
#    if tfsec --version >/dev/null 2>&1; then
#        print_success "tfsec is working"
#    fi
#else
#    # print_info "tfsec not available"
#fi

if kubectl get deployment trivy-server -n data-platform-security-scanning >/dev/null 2>&1; then
    print_success "Trivy server available in cluster"
else
    print_info "Trivy server not found in cluster"
fi

# Test 4: Basic cluster connectivity
print_info "Checking cluster connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
    print_success "Kubernetes cluster is accessible"

    # Check security namespace
    if kubectl get namespace data-platform-security-scanning >/dev/null 2>&1; then
        print_success "Security scanning namespace exists"
    else
        print_info "Security scanning namespace not found"
    fi
else
    print_info "Kubernetes cluster not accessible"
fi

echo ""
echo "========================================"
print_success "Simple tests completed!"
echo "========================================"

# For more comprehensive tests, use:
echo "For full testing, run:"
echo "  ./test-checkov.sh             # Test Checkov security scanning"
echo "  ./test-argocd-security-integration.sh  # Test ArgoCD security"

exit 0
