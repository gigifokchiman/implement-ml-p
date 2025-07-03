#!/bin/bash

# Build Docker image with terraform-provider-kind
# This script handles copying the macOS terraform provider binary for Docker builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🐋 Building ML Platform Infrastructure Docker Image"

# Check if terraform-provider-mlplatform exists in the project root
if [ -f "$PROJECT_ROOT/terraform-provider-mlplatform" ]; then
    echo "✅ Found terraform-provider-mlplatform binary"
    # Copy it to infrastructure directory for Docker build context
    cp "$PROJECT_ROOT/terraform-provider-mlplatform" "$SCRIPT_DIR/"
    echo "📁 Copied terraform-provider-mlplatform to build context"
else
    echo "⚠️  terraform-provider-mlplatform binary not found in project root"
    echo "   The Docker image will be built without the pre-built provider"
    echo "   You can still mount the provider at runtime or install it later"
fi

# Check if terraform-provider-kind source exists
if [ -d "$SCRIPT_DIR/terraform-provider-kind" ]; then
    echo "✅ Found terraform-provider-kind source directory"
else
    echo "⚠️  terraform-provider-kind source not found"
    echo "   If you have the source, place it in infrastructure/terraform-provider-kind/"
fi

echo "🔨 Building Docker image..."

# Build the Docker image
docker build -t ml-platform-tools:latest "$SCRIPT_DIR"

# Clean up copied binary
if [ -f "$SCRIPT_DIR/terraform-provider-mlplatform" ]; then
    rm "$SCRIPT_DIR/terraform-provider-mlplatform"
    echo "🧹 Cleaned up copied binary"
fi

echo ""
echo "✅ Docker image built successfully!"
echo ""
echo "📋 Usage:"
echo "   # Run the container with Docker socket mounted"
echo "   docker run -it --rm --user root \\"
echo "     -v /var/run/docker.sock:/var/run/docker.sock \\"
echo "     -v \$(pwd):/workspace \\"
echo "     --network host \\"
echo "     ml-platform-tools:latest"
echo ""
echo "   # Or mount the terraform provider from host (if not built into image)"
echo "   docker run -it --rm --user root \\"
echo "     -v /var/run/docker.sock:/var/run/docker.sock \\"
echo "     -v \$(pwd):/workspace \\"
echo "     -v \$HOME/.terraform.d:/root/.terraform.d \\"
echo "     --network host \\"
echo "     ml-platform-tools:latest"
echo ""
echo "   # Check if terraform provider is available"
echo "   docker run --rm ml-platform-tools:latest health-check.sh"
echo ""