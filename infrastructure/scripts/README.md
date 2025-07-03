# Infrastructure Scripts

Organized automation scripts for ML platform infrastructure management.

## 🚀 Quick Commands

```bash
# Local development deployment
./deployment/deploy-local.sh

# Clean up everything
./management/cleanup-infrastructure.sh

# Show infrastructure status
./utilities/show-infrastructure.sh
```

## 📂 Directory Structure

### `deployment/`

**Infrastructure deployment and environment setup**

| Script            | Purpose                        | Usage                                          |
|-------------------|--------------------------------|------------------------------------------------|
| `deploy-local.sh` | Complete local Kind deployment | `./deployment/deploy-local.sh [--clean-first]` |
| `deploy.sh`       | Multi-environment deployment   | `./deployment/deploy.sh <environment>`         |

### `management/`

**Infrastructure lifecycle management**

| Script                      | Purpose                          | Usage                                     |
|-----------------------------|----------------------------------|-------------------------------------------|
| `argocd-manage.sh`          | ArgoCD operations and management | `./management/argocd-manage.sh <command>` |
| `bootstrap-argocd.sh`       | Initial ArgoCD setup             | `./management/bootstrap-argocd.sh`        |
| `cleanup-infrastructure.sh` | Clean up all resources           | `./management/cleanup-infrastructure.sh`  |

### `utilities/`

**Development and maintenance utilities**

| Script                   | Purpose                           | Usage                                        |
|--------------------------|-----------------------------------|----------------------------------------------|
| `docker-infra.sh`        | Docker-based infrastructure tools | `./utilities/docker-infra.sh <command>`      |
| `generate-certs.sh`      | TLS certificate generation        | `./utilities/generate-certs.sh`              |
| `show-infrastructure.sh` | Infrastructure status display     | `./utilities/show-infrastructure.sh`         |
| `tf-wrapper.sh`          | Terraform wrapper with validation | `./utilities/tf-wrapper.sh <terraform-args>` |

### `helpers/`

**Specialized helper scripts**

| Script                       | Purpose                            | Usage                                  |
|------------------------------|------------------------------------|----------------------------------------|
| `fix-kind-storage.sh`        | Fix Kind storage issues            | `./helpers/fix-kind-storage.sh`        |
| `install-prometheus-crds.sh` | Install Prometheus CRDs            | `./helpers/install-prometheus-crds.sh` |
| `install-graphviz.sh`        | Install Graphviz for visualization | `./helpers/install-graphviz.sh`        |

### `visualization/`

**Infrastructure visualization suite**

| Script                        | Purpose                           | Usage                                         |
|-------------------------------|-----------------------------------|-----------------------------------------------|
| `visualize-infrastructure.sh` | Complete visualization suite      | `./visualization/visualize-infrastructure.sh` |
| `terraform-visualize.sh`      | Terraform infrastructure diagrams | `./visualization/terraform-visualize.sh`      |
| `kubernetes-visualize.sh`     | Kubernetes application diagrams   | `./visualization/kubernetes-visualize.sh`     |
| `argocd-visualize.sh`         | ArgoCD GitOps workflow diagrams   | `./visualization/argocd-visualize.sh`         |
| `mcp-wrapper.py`              | AI-assisted visualization via MCP | Used by AI assistants                         |

## 🛠️ Common Workflows

### **Local Development Setup**

```bash
# Option 1: Full deployment
./deployment/deploy-local.sh

# Option 2: Clean deployment
./deployment/deploy-local.sh --clean-first

# Option 3: Manual setup
cd ../terraform/environments/local
terraform init && terraform apply
cd ../../../scripts
./management/bootstrap-argocd.sh
```

### **Infrastructure Management**

```bash
# Check status
./utilities/show-infrastructure.sh

# Manage ArgoCD
./management/argocd-manage.sh status
./management/argocd-manage.sh sync-apps

# Clean up resources
./management/cleanup-infrastructure.sh
```

### **Troubleshooting**

```bash
# Fix Kind storage issues
./helpers/fix-kind-storage.sh

# Install missing Prometheus CRDs
./helpers/install-prometheus-crds.sh

# Use Docker container for tools
./utilities/docker-infra.sh shell
```

### **Infrastructure Visualization**

```bash
# Generate complete visualization suite
./visualization/visualize-infrastructure.sh -o

# Terraform infrastructure only
./visualization/terraform-visualize.sh -e prod --use-rover

# Kubernetes applications only
./visualization/kubernetes-visualize.sh --live-cluster

# ArgoCD GitOps workflows
./visualization/argocd-visualize.sh -e staging -f svg

# Install Graphviz dependency
./helpers/install-graphviz.sh
```

## 🔧 Script Features

### **Error Handling**

- All scripts use `set -euo pipefail` for strict error handling
- Comprehensive error messages with color coding
- Graceful cleanup on failure

### **Logging**

- Standardized logging functions (`log_info`, `log_success`, `log_warn`, `log_error`)
- Color-coded output for better visibility
- Progress tracking for long-running operations

### **Prerequisites Check**

- Automatic tool detection (terraform, kubectl, docker, kind)
- Version compatibility checks where needed
- Clear error messages for missing dependencies

## 📋 Environment Variables

Common environment variables used across scripts:

```bash
# Cluster configuration
export CLUSTER_NAME="ml-platform-local"
export KUBECONFIG="~/.kube/config"

# ArgoCD configuration
export ARGOCD_NAMESPACE="argocd"
export ARGOCD_SERVER="argocd.ml-platform.local:30080"

# Terraform configuration
export TF_VAR_cluster_name="ml-platform-local"
export TF_LOG="INFO"
```

## 🚨 Important Notes

### **Backward Compatibility**

- Legacy script paths are maintained with symlinks/wrappers
- Existing documentation references remain valid
- Gradual migration approach for existing users

### **Security Considerations**

- Scripts validate inputs and environments
- No hardcoded secrets or credentials
- Secure defaults for all configurations

### **Testing**

- All scripts include dry-run capabilities where applicable
- Integration with the test framework in `../tests/`
- Validation steps before destructive operations

## 🔗 Related Documentation

- [**Deployment Guide**](../docs/operations/deployment.md) - Complete deployment procedures
- [**ArgoCD Guide**](../docs/operations/argocd-guide.md) - GitOps workflows
- [**Troubleshooting**](../docs/troubleshooting/common-issues.md) - Common issues and solutions
- [**Docker Setup**](../docs/setup/docker-setup.md) - Container-based development

---

**Last Updated:** January 2025  
**Organization:** Improved script organization for better maintainability
