# Docker-based Infrastructure Management

This document describes how to use Docker containers for infrastructure management with the custom
terraform-provider-kind.

**Last Updated:** January 2025  
**Repository:** https://github.com/gigifokchiman/implement-ml-p

## Overview

The infrastructure container includes all necessary tools:

- **Terraform** (1.6.6) - Infrastructure as Code
- **kubectl** (1.28.4) - Kubernetes CLI
- **Helm** (3.13.3) - Kubernetes package manager
- **Kind** (0.20.0) - Local Kubernetes clusters
- **Custom Kind Provider** (gigifokchiman/kind v0.1.0) - Custom terraform provider
- **Docker CLI** (latest) - Container management
- **AWS CLI** (2.15.7) - AWS services
- **Security Tools**: Checkov, tfsec, Terrascan, OPA, Conftest
- **Monitoring Tools**: promtool, k6
- **Utilities**: yq, jq, kustomize, kubectx, kubens, k9s

## Prerequisites

Before building the Docker image, ensure you have the terraform provider binary:

```bash
# Copy your macOS terraform provider to the project root
cp terraform-provider-mlplatform ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/darwin_arm64/terraform-provider-kind_v0.1.0 ./terraform-provider-mlplatform
```

## Quick Start

### 1. Build Container with Terraform Provider

```bash
# Build the infrastructure tools image with the terraform provider
cd infrastructure
./build-docker-with-provider.sh
```

This script will:

- Look for `terraform-provider-mlplatform` in the project root
- Copy it to the Docker build context
- Build the image with the provider included
- Clean up the temporary files

### 2. Run Container

```bash
# Run with Docker socket mounted (for Kind)
docker run -it --rm --user root \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  --network host \
  ml-platform-tools:latest

# Alternative: Mount terraform plugins from host
docker run -it --rm --user root \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -v $HOME/.terraform.d:/root/.terraform.d \
  --network host \
  ml-platform-tools:latest
```

### 3. Verify Installation

```bash
# Check all tools are available
health-check.sh

# Check terraform provider specifically
terraform providers
```

## Infrastructure Deployment

### Local Environment with Kind

```bash
# Inside the container
cd infrastructure/terraform/environments/local

# Initialize terraform (should detect the custom provider)
terraform init

# Deploy the infrastructure
terraform apply

# Bootstrap ArgoCD
cd ../../../
./scripts/bootstrap-argocd.sh
```

### Verify Deployment

```bash
# Check Kind cluster
kind get clusters

# Check terraform provider
ls -la ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/

# Check ArgoCD
kubectl get pods -n argocd
```

## Advanced Usage

### With Docker Compose

You can also use the infrastructure container alongside your application services:

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  infrastructure:
    build:
      context: ./infrastructure
      dockerfile: Dockerfile
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - .:/workspace
      - ~/.terraform.d:/root/.terraform.d
    working_dir: /workspace
    network_mode: host
    command: tail -f /dev/null
```

### Mounting Configurations

```bash
# Mount additional configurations
docker run -it --rm --user root \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -v ~/.terraform.d:/root/.terraform.d \
  -v ~/.kube:/root/.kube \
  -v ~/.aws:/root/.aws \
  --network host \
  ml-platform-tools:latest
```

## Troubleshooting

### Terraform Provider Issues

```bash
# Check if provider is installed
terraform providers

# Check provider location
ls -la ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/

# Manual install inside container
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/linux_$(uname -m)
# Copy provider binary to this location
```

### Kind Provider Binary

If the provider isn't working:

1. **Check Architecture**: Ensure the binary matches the container architecture
2. **Check Permissions**: Provider binary should be executable
3. **Check Path**: Provider should be in the correct terraform plugins directory

```bash
# Fix permissions
chmod +x ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/*/terraform-provider-kind*

# Check if terraform can find it
terraform providers
```

### Docker Socket Issues

```bash
# Ensure Docker socket is accessible
ls -la /var/run/docker.sock

# Check Docker is working inside container
docker ps
```

## Container Management

### Useful Aliases

```bash
# Add to your ~/.bashrc or ~/.zshrc
alias infra-shell='docker run -it --rm --user root \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  --network host \
  ml-platform-tools:latest'

alias infra-run='docker run --rm --user root \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  --network host \
  ml-platform-tools:latest'
```

### Usage Examples

```bash
# Quick terraform command
infra-run terraform version

# Interactive shell
infra-shell

# Run specific script
infra-run ./scripts/deploy-local.sh
```

## Security Considerations

- The container runs as root to access Docker socket
- Docker socket mounting gives container full Docker access
- Use only in trusted environments
- Consider using rootless Docker for additional security

## Container Updates

```bash
# Rebuild with latest tools
./build-docker-with-provider.sh

# Or update specific components
docker build --no-cache -t ml-platform-tools:latest .
```

---

This Docker setup provides a consistent, isolated environment for infrastructure management while supporting the custom
terraform-provider-kind required for the ML platform.
