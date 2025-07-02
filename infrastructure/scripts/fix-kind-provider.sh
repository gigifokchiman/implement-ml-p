#!/bin/bash
# Fix terraform-provider-kind checksum issues
# This script resolves the common "checksums don't match" error

set -e

echo "🔧 Fixing terraform-provider-kind checksum issues..."

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/local"

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

echo "📍 Working in: $(pwd)"

# Step 1: Clean up existing terraform state
echo "🧹 Cleaning up existing Terraform cache..."
rm -f .terraform.lock.hcl
rm -rf .terraform

# Step 2: Check if custom provider needs to be built
PROVIDER_DIR="$SCRIPT_DIR/../terraform-provider-kind"
if [ -d "$PROVIDER_DIR" ]; then
    echo "🔨 Building custom terraform-provider-kind..."
    cd "$PROVIDER_DIR"
    
    # Ensure Go modules are up to date
    go mod tidy
    
    # Build the provider
    go build -o terraform-provider-kind
    
    # Create plugin directory for current platform
    PLUGIN_DIR="$HOME/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/$(go env GOOS)_$(go env GOARCH)"
    mkdir -p "$PLUGIN_DIR"
    
    # Copy provider to plugin directory
    cp terraform-provider-kind "$PLUGIN_DIR/"
    
    echo "✅ Custom provider built and installed to: $PLUGIN_DIR"
    
    # Go back to terraform directory
    cd "$TERRAFORM_DIR"
else
    echo "⚠️  Custom provider directory not found: $PROVIDER_DIR"
    echo "    Continuing with standard provider installation..."
fi

# Step 3: Reinitialize Terraform
echo "🚀 Initializing Terraform with new checksums..."
terraform init --upgrade

echo "✅ terraform-provider-kind checksum issues resolved!"
echo ""
echo "You can now run:"
echo "  terraform plan"
echo "  terraform apply"