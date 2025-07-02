# Docker-based Infrastructure Management

This document describes how to use Docker containers for infrastructure management instead of installing tools locally
with brew.

## Overview

The infrastructure container includes all necessary tools:

- **Terraform** (1.6.6) - Infrastructure as Code
- **kubectl** (1.28.4) - Kubernetes CLI
- **Helm** (3.13.3) - Kubernetes package manager
- **Kind** (0.20.0) - Local Kubernetes clusters
- **Docker CLI** (24.0.7) - Container management
- **AWS CLI** (2.15.7) - AWS services
- **Security Tools**: Checkov, tfsec, Terrascan, OPA, Conftest
- **Monitoring Tools**: promtool, k6
- **Utilities**: yq, jq, kustomize, kubectx, kubens, k9s

## Quick Start

### 1. Build and Start Container

```bash
# Build the infrastructure tools image
make docker-build

# Start the container in background
make docker-run

# Open shell in the container
make docker-shell
```

### 2. Alternative: Complete Setup

```bash
# Complete setup in one command
make docker-dev-setup
```

### 3. Using Infrastructure Tools

Once inside the container shell:

```bash
# Initialize local environment
cd terraform/environments/local
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## Make Commands

### Setup Commands

| Command                 | Description                             |
|-------------------------|-----------------------------------------|
| `make docker-build`     | Build infrastructure tools Docker image |
| `make docker-run`       | Start container in background           |
| `make docker-shell`     | Open shell in container                 |
| `make docker-dev-setup` | Complete Docker development setup       |

### Terraform Commands (Docker-based)

| Command                   | Description                     |
|---------------------------|---------------------------------|
| `make docker-init-local`  | Initialize local environment    |
| `make docker-plan-local`  | Plan local environment changes  |
| `make docker-apply-local` | Apply local environment changes |
| `make docker-init-dev`    | Initialize dev environment      |
| `make docker-plan-dev`    | Plan dev environment changes    |
| `make docker-apply-dev`   | Apply dev environment changes   |

### Utility Commands

| Command                     | Description                       |
|-----------------------------|-----------------------------------|
| `make docker-format`        | Format Terraform files            |
| `make docker-validate`      | Validate Terraform configurations |
| `make docker-test`          | Run infrastructure tests          |
| `make docker-security-scan` | Run security scans                |

### Management Commands

| Command                    | Description               |
|----------------------------|---------------------------|
| `make docker-logs`         | View container logs       |
| `make docker-health`       | Check container health    |
| `make docker-stop`         | Stop container            |
| `make docker-clean`        | Clean up Docker resources |
| `make docker-dev-teardown` | Complete teardown         |

## Directory Structure

The container mounts the following directories:

```
/workspace/                 # Working directory in container
├── terraform/             # Terraform configurations
├── kubernetes/            # Kubernetes manifests
├── tests/                 # Infrastructure tests
├── scripts/               # Helper scripts
├── .kube/                 # Kubernetes configuration
├── .aws/                  # AWS credentials
└── .ssh/                  # SSH keys for Git
```

## Volume Mounts

The docker-compose setup mounts:

- **Project directory**: `.:/workspace` (read-write)
- **Docker socket**: `/var/run/docker.sock` (for Kind and Docker commands)
- **Kubernetes config**: `~/.kube:/workspace/.kube` (read-only)
- **AWS credentials**: `~/.aws:/workspace/.aws` (read-only)
- **SSH keys**: `~/.ssh:/workspace/.ssh` (read-only)
- **Terraform cache**: `terraform-cache` volume
- **Helm cache**: `helm-cache` volume

## Environment Variables

The container is configured with:

```bash
# Terraform
TF_LOG=INFO
TF_LOG_PATH=/workspace/terraform.log
TF_IN_AUTOMATION=1
TF_INPUT=0

# Kubernetes
KUBECONFIG=/workspace/.kube/config

# AWS
AWS_PROFILE=default
AWS_DEFAULT_REGION=us-west-2

# Tool configurations
HELM_CACHE_HOME=/workspace/.cache/helm
CHECKOV_LOG_LEVEL=INFO
```

## Security Features

### Container Security

- Runs as non-root user (`infrauser`)
- Minimal base image (Ubuntu 22.04)
- No unnecessary packages
- Separate user namespace

### Tool Security

- All security scanning tools included
- Automated security checks with `make docker-security-scan`
- Container image vulnerability scanning
- Terraform security scanning with multiple tools

### Access Control

- Read-only mounts for sensitive directories
- Isolated container network
- No privileged access required

## Development Workflow

### Option 1: Interactive Shell

```bash
# Start container and open shell
make docker-dev-setup
make docker-shell

# Inside container
cd terraform/environments/local
terraform init
terraform plan
terraform apply
```

### Option 2: Direct Commands

```bash
# Build and start container
make docker-build
make docker-run

# Run commands directly
make docker-init-local
make docker-plan-local
make docker-apply-local
```

### Option 3: Native + Docker Hybrid

```bash
# Use native tools for development
make init-local
make plan-local

# Use Docker for security scanning
make docker-security-scan

# Use Docker for testing
make docker-test
```

## Troubleshooting

### Container Won't Start

```bash
# Check Docker daemon
docker ps

# Check for port conflicts
docker-compose -f docker-compose.infra.yml ps

# Check logs
make docker-logs
```

### Permission Issues

```bash
# Ensure Docker socket is accessible
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group
sudo usermod -aG docker $USER
```

### Tool Versions

```bash
# Check all tool versions
make docker-health

# Or manually inside container
make docker-shell
# Inside container:
health-check.sh
```

### AWS/Kubernetes Access

```bash
# Ensure credentials are mounted correctly
ls -la ~/.aws
ls -la ~/.kube

# Test inside container
make docker-shell
# Inside container:
aws sts get-caller-identity
kubectl cluster-info
```

## Advanced Usage

### Custom Tool Versions

Edit `Dockerfile` to change tool versions:

```dockerfile
ENV TERRAFORM_VERSION=1.7.0
ENV KUBECTL_VERSION=v1.29.0
```

Then rebuild:

```bash
make docker-clean
make docker-build
```

### Additional Tools

Add tools to `Dockerfile`:

```dockerfile
# Install additional tool
RUN curl -L -o tool https://example.com/tool && \
    chmod +x tool && \
    mv tool /usr/local/bin/
```

### CI/CD Integration

Use in CI/CD pipelines:

```yaml
# GitHub Actions example
jobs:
  infrastructure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build infra tools
        run: make docker-build
      - name: Run security scan
        run: make docker-security-scan
      - name: Deploy to staging
        run: make docker-apply-staging
```

## Performance Optimization

### Image Caching

The image uses multi-stage builds and layer caching for faster builds.

### Volume Caching

Terraform and Helm caches are persisted in Docker volumes:

```bash
# List cache volumes
docker volume ls | grep -E "(terraform|helm)-cache"

# Clear caches if needed
docker volume rm infrastructure_terraform-cache
docker volume rm infrastructure_helm-cache
```

### Resource Limits

Configure resource limits in `docker-compose.infra.yml`:

```yaml
services:
  infra-tools:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

## Benefits of Docker Approach

1. **Consistency**: Same tools and versions across all environments
2. **Isolation**: No conflicts with local tool installations
3. **Security**: Sandboxed execution environment
4. **Portability**: Works on any system with Docker
5. **Reproducibility**: Exact same environment for all team members
6. **CI/CD Ready**: Easy integration with automation pipelines
7. **Version Management**: Centralized tool version control
8. **Clean System**: No need to install tools locally

## Migration from Brew

To migrate from brew-based setup:

1. **Backup existing configurations**:
   ```bash
   cp -r ~/.kube ~/.kube.backup
   cp -r ~/.aws ~/.aws.backup
   ```

2. **Stop using brew tools**:
   ```bash
   # Uninstall brew tools (optional)
   brew uninstall terraform kubectl helm
   ```

3. **Start using Docker**:
   ```bash
   make docker-dev-setup
   make docker-health
   ```

4. **Update shell aliases** (optional):
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   alias tf='docker exec ml-platform-infra-tools terraform'
   alias kubectl='docker exec ml-platform-infra-tools kubectl'
   alias helm='docker exec ml-platform-infra-tools helm'
   ```

This approach provides a more reliable, consistent, and secure infrastructure management experience.
