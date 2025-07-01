# ML Platform Infrastructure Installation Manual

This manual provides step-by-step instructions for setting up the ML Platform infrastructure on your local machine and
cloud environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Installation](#detailed-installation)
4. [Environment Setup](#environment-setup)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Next Steps](#next-steps)

## Prerequisites

### Required Tools

| Tool       | Version | Purpose                        | Installation                                                                                                |
|------------|---------|--------------------------------|-------------------------------------------------------------------------------------------------------------|
| Docker     | 20.10+  | Container runtime              | [Docker Desktop](https://www.docker.com/products/docker-desktop)                                            |
| Kubernetes | 1.27+   | Container orchestration        | Included with Docker Desktop                                                                                |
| Kind       | 0.20+   | Local Kubernetes clusters      | `brew install kind` or [Kind Releases](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)        |
| Terraform  | 1.0+    | Infrastructure as Code         | `brew install terraform` or [Terraform Downloads](https://www.terraform.io/downloads)                       |
| kubectl    | 1.27+   | Kubernetes CLI                 | `brew install kubectl` or [kubectl Install](https://kubernetes.io/docs/tasks/tools/)                        |
| Kustomize  | 5.0+    | Kubernetes configuration       | `brew install kustomize` or [Kustomize Install](https://kubectl.docs.kubernetes.io/installation/kustomize/) |
| Go         | 1.16+   | For custom provider (optional) | `brew install go` or [Go Downloads](https://golang.org/dl/)                                                 |

### Optional Tools

| Tool | Purpose            | Installation        |
|------|--------------------|---------------------|
| Helm | Package management | `brew install helm` |
| jq   | JSON processing    | `brew install jq`   |
| yq   | YAML processing    | `brew install yq`   |
| gh   | GitHub CLI         | `brew install gh`   |

### System Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 20GB free space
- **OS**: macOS, Linux, or WSL2 on Windows

## Quick Start

For experienced users who want to get up and running quickly:

```bash
# Clone the repository
git clone --recurse-submodules https://github.com/your-org/ml-platform.git
cd ml-platform

# Run the setup script
./scripts/setup.sh

# Deploy local environment
cd infrastructure/terraform/environments/local
terraform init
terraform apply -auto-approve

# Deploy applications
kubectl apply -k infrastructure/kubernetes/overlays/local

# Verify deployment
kubectl get pods -n ml-platform
```

## Detailed Installation

### Step 1: Clone Repository

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/your-org/ml-platform.git
cd ml-platform

# If already cloned, initialize submodules
git submodule update --init --recursive
```

### Step 2: Verify Prerequisites

Run the prerequisite check script:

```bash
./scripts/check-prerequisites.sh
```

This script will:

- Check all required tools are installed
- Verify minimum versions
- Test Docker connectivity
- Check available resources

### Step 3: Configure Environment

#### Local Development

1. Copy environment template:
   ```bash
   cp infrastructure/.env.example infrastructure/.env
   ```

2. Edit configuration (optional):
   ```bash
   # Edit if you need custom settings
   vi infrastructure/.env
   ```

3. Default settings:
   ```bash
   CLUSTER_NAME=ml-platform-local
   REGISTRY_PORT=5001
   INGRESS_HTTP_PORT=8080
   INGRESS_HTTPS_PORT=8443
   ```

#### Cloud Environments

For AWS deployment:

```bash
# Configure AWS credentials
export AWS_PROFILE=your-profile
# or
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=us-east-1
```

### Step 4: Build Infrastructure

#### Option A: Using Go 1.16+ (Custom Provider)

If you have Go 1.16 or later:

```bash
# Build and install custom Kind provider
cd infrastructure
./terraform-provider-kind-setup.sh

# Initialize Terraform
cd terraform/environments/local
terraform init
```

#### Option B: Using Go 1.13-1.15 (Third-Party Provider)

If you have an older Go version:

```bash
# The configuration already uses the third-party provider
cd infrastructure/terraform/environments/local
terraform init -upgrade
```

### Step 5: Deploy Infrastructure

#### Local Environment

1. Create Kind cluster and registry:
   ```bash
   cd infrastructure/terraform/environments/local
   terraform plan
   terraform apply
   ```

2. Wait for confirmation:
   ```
   Do you want to perform these actions?
   Enter a value: yes
   ```

3. Verify cluster:
   ```bash
   kubectl cluster-info --context kind-ml-platform-local
   ```

#### Cloud Environments

For development environment:

```bash
cd infrastructure/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 6: Deploy Applications

#### Using Kustomize

```bash
# Deploy to local Kind cluster
kubectl apply -k infrastructure/kubernetes/overlays/local

# Monitor deployment
kubectl get pods -n ml-platform -w
```

#### Using Helm (Optional)

```bash
# Add Helm repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install services
helm install redis bitnami/redis -n ml-platform
```

## Environment Setup

### Local Development

The local environment includes:

- 3-node Kind cluster (1 control plane, 2 workers)
- Local Docker registry on port 5001
- Ingress controller on ports 8080/8443
- Persistent volumes for data

### Accessing Services

After deployment, services are available at:

| Service     | URL                           | Credentials |
|-------------|-------------------------------|-------------|
| Frontend    | http://localhost:8080         | N/A         |
| API Gateway | http://localhost:8080/api     | See secrets |
| Registry    | http://localhost:5001         | dev/dev     |
| Metrics     | http://localhost:8080/metrics | admin/admin |

### Registry Configuration

Configure Docker to use the local registry:

```bash
# Add insecure registry to Docker daemon
# On macOS: Docker Desktop > Preferences > Docker Engine
{
  "insecure-registries": ["localhost:5001"]
}

# Restart Docker Desktop
```

## Verification

### Run Test Suite

```bash
# Run all infrastructure tests
cd infrastructure/tests
./run-all.sh

# Run specific tests
./run-all.sh --type basic
./run-all.sh --type extended --skip-performance
```

### Manual Verification

1. Check cluster nodes:
   ```bash
   kubectl get nodes
   ```

2. Check system pods:
   ```bash
   kubectl get pods -A
   ```

3. Check applications:
   ```bash
   kubectl get all -n ml-platform
   ```

4. Test ingress:
   ```bash
   curl http://localhost:8080/health
   ```

## Troubleshooting

### Common Issues

#### 1. Kind cluster creation fails

```bash
# Check Docker is running
docker info

# Clean up existing clusters
kind delete cluster --name ml-platform-local

# Retry with more resources
terraform apply -var="worker_nodes=1"
```

#### 2. Provider not found

```bash
# For custom provider
./terraform-provider-kind-setup.sh

# For third-party provider
terraform init -upgrade
```

#### 3. Port conflicts

```bash
# Check port usage
lsof -i :8080
lsof -i :5001

# Use different ports
terraform apply -var="registry_port=5002" -var="ingress_http_port=8081"
```

#### 4. Insufficient resources

```bash
# Reduce cluster size
terraform apply -var="worker_nodes=1"

# Or increase Docker resources
# Docker Desktop > Preferences > Resources
```

### Debug Commands

```bash
# Check Kind cluster logs
kind export logs --name ml-platform-local

# Check pod logs
kubectl logs -n ml-platform <pod-name>

# Describe failing resources
kubectl describe pod -n ml-platform <pod-name>

# Check events
kubectl get events -n ml-platform --sort-by='.lastTimestamp'
```

## Next Steps

### 1. Deploy Sample Application

```bash
# Deploy sample ML model
kubectl apply -f examples/ml-model/

# Access model endpoint
curl http://localhost:8080/api/v1/predict
```

### 2. Set Up CI/CD

```bash
# Configure GitHub Actions
cp .github/workflows/ci-cd.yml.example .github/workflows/ci-cd.yml

# Set up secrets in GitHub
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
```

### 3. Configure Monitoring

```bash
# Deploy Prometheus and Grafana
kubectl apply -k infrastructure/kubernetes/monitoring/

# Access dashboards
# Grafana: http://localhost:8080/grafana
# Prometheus: http://localhost:8080/prometheus
```

### 4. Development Workflow

```bash
# Build and push images
docker build -t localhost:5001/ml-app:latest .
docker push localhost:5001/ml-app:latest

# Update deployment
kubectl set image deployment/ml-app ml-app=localhost:5001/ml-app:latest -n ml-platform

# Watch rollout
kubectl rollout status deployment/ml-app -n ml-platform
```

## Cleanup

### Local Environment

```bash
# Destroy infrastructure
cd infrastructure/terraform/environments/local
terraform destroy -auto-approve

# Remove registry data
rm -rf registry-data/

# Clean up Docker
docker system prune -af
```

### Complete Cleanup

```bash
# Remove all Kind clusters
kind delete clusters --all

# Remove Terraform state
rm -rf infrastructure/terraform/environments/*/.terraform*
rm -rf infrastructure/terraform/environments/*/terraform.tfstate*

# Remove provider
rm -rf ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/
```

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review logs: `./scripts/collect-logs.sh`
3. Open issue: https://github.com/your-org/ml-platform/issues
4. Team chat: #ml-platform-support

## Appendix

### Environment Variables

```bash
# Core settings
export KUBECONFIG=$HOME/.kube/config
export KUBE_CONTEXT=kind-ml-platform-local

# Development settings
export REGISTRY_URL=localhost:5001
export ENVIRONMENT=local

# AWS settings (for cloud deployments)
export AWS_PROFILE=ml-platform-dev
export AWS_REGION=us-east-1
```

### Useful Aliases

Add to your shell profile:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kml='kubectl -n ml-platform'
alias kctx='kubectl config use-context'

# Project aliases
alias mlp='cd ~/path/to/ml-platform'
alias mlpi='cd ~/path/to/ml-platform/infrastructure'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
```

### VS Code Extensions

Recommended extensions for development:

- Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools)
- Terraform (hashicorp.terraform)
- YAML (redhat.vscode-yaml)
- Go (golang.go)
- GitLens (eamodio.gitlens)

---

**Version**: 1.0.0  
**Last Updated**: 2024-01-15  
**Maintained By**: Platform Team
