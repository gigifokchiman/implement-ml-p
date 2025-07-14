# 🚀 New Engineer Runbook

> **Complete hands-on guide for new engineers to experience the modern ML platform infrastructure with team isolation
and security.**

## 📋 Table of Contents

1. [Overview](#-overview)
2. [Prerequisites](#-prerequisites)
3. [Phase 1: Platform Deployment](#-phase-1-single-cluster-team-platform)
4. [Phase 2: Testing & Validation](#-phase-2-testing--validation)
5. [Phase 3: Advanced Topics](#-phase-3-advanced-topics)
6. [Learning Summary](#-learning-summary)
7. [Troubleshooting](#-troubleshooting)
8. [Cleanup](#-cleanup)

---

## 🎯 Overview

This runbook guides you through the **modern ML platform infrastructure approach** - single cluster with team isolation
and Kubernetes-native security.

### What You'll Accomplish

By the end of this runbook, you'll have:

- ✅ **Deployed** a production-ready single cluster with team boundaries
- ✅ **Experienced** resource quotas, RBAC, and network policies
- ✅ **Implemented** enterprise-grade security without service mesh complexity
- ✅ **Tested** the complete team isolation and monitoring setup
- ✅ **Prepared** for secure, scalable application development

### Key Metrics

- **Estimated Time:** 3-4 hours (single session)
- **Architecture:** Single cluster with namespace isolation
- **Benefits:** 80% of multi-cluster benefits, 20% of complexity

### System Requirements

| Component   | Requirement     | Recommended    |
|-------------|-----------------|----------------|
| **CPU**     | 4+ cores        | 8+ cores       |
| **RAM**     | 8GB minimum     | 16GB           |
| **Storage** | 20GB free space | 50GB           |
| **OS**      | macOS/Linux     | macOS (tested) |

### Repository Setup

```bash
# Clone the repository
git clone https://github.com/gigifokchiman/implement-ml-p.git
cd implement-ml-p

# Verify structure
ls -la infrastructure/
```

---

## 📋 Prerequisites

Choose your preferred setup approach:

### Option A: Local Tool Installation 🔧

**Required Tools:**

```bash
# Update package manager
brew update && brew upgrade
```

| Tool          | Version  | Purpose                    | Installation                                                     |
|---------------|----------|----------------------------|------------------------------------------------------------------|
| **AWS CLI**   | 2.0+     | AWS cloud operations       | `brew install awscli`                                            |
| **Docker**    | 20.10+   | Container runtime          | [Docker Desktop](https://www.docker.com/products/docker-desktop) |
| **Git**       | 2.30+    | Version control            | `brew install git`                                               |
| **Kind**      | 0.20+    | Local Kubernetes clusters  | `brew install kind`                                              |
| **kubectl**   | 1.27+    | Kubernetes CLI             | `brew install kubectl`                                           |
| **Kustomize** | 5.0+     | Kubernetes configuration   | `brew install kustomize`                                         |
| **Helm**      | v3.18.3+ | Kubernetes package manager | `brew install helm`                                              |
| **Terraform** | 1.0+     | Infrastructure as Code     | `brew install terraform`                                         |

**Custom Terraform Provider Setup:**

```bash
# Detect your architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    TERRAFORM_ARCH="darwin_amd64"
elif [ "$ARCH" = "arm64" ]; then
    TERRAFORM_ARCH="darwin_arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Create terraform plugins directory
mkdir -p ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/$TERRAFORM_ARCH

# Download and install the provider
wget https://github.com/gigifokchiman/kind/releases/download/v0.1.0/terraform-provider-kind_v0.1.0_${TERRAFORM_ARCH}.tar.gz \
  -O /tmp/terraform-provider-kind.tar.gz

cd /tmp && tar -xzf terraform-provider-kind.tar.gz
cp terraform-provider-kind_v0.1.0 ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/$TERRAFORM_ARCH/terraform-provider-kind

# Make it executable and clean up
chmod +x ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/$TERRAFORM_ARCH/terraform-provider-kind
rm -f /tmp/terraform-provider-kind*
```

**Verification:**

```bash
# Verify all tool installations
awscli --version
docker --version
git version
kind --version
kubectl version --client
kustomize version
helm version
terraform --version

# Verify custom terraform provider
ls -la ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.4/*/terraform-provider-kind

# Navigate to infrastructure directory
cd infrastructure
```

**Optional Tools:**

| Tool         | Purpose            | Installation            |
|--------------|--------------------|-------------------------|
| **gh**       | GitHub CLI         | `brew install gh`       |
| **jq**       | JSON processing    | `brew install jq`       |
| **yq**       | YAML processing    | `brew install yq`       |
| **k6**       | Load testing       | `brew install k6`       |
| **trivy**    | Security scanning  | `brew install trivy`    |
| **graphviz** | Diagram generation | `brew install graphviz` |

### Option B: Docker-Only Approach 🐳 (Recommended)

**Benefits:**

- ✅ No local tool installation required
- ✅ Consistent tool versions across team members
- ✅ All security scanners pre-installed
- ✅ Performance and monitoring tools included

**Setup:**

```bash
# Update package manager
brew update && brew upgrade

# Verify Docker installation
docker --version
docker info

# Build the infrastructure tools container
cd infrastructure
docker build -t ml-platform-tools .

# Verify all tools are working
docker run --rm ml-platform-tools health-check.sh

# Start the container with proper access
docker run -it --rm --user root \
  --network host \
  -v ~/.docker/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -v ~/.aws:/workspace/.aws:ro \
  -v ~/.kube:/workspace/.kube \
  ml-platform-tools
```

> **🔍 Important:** `--network host` is REQUIRED for kubectl to access the Kind cluster

---

## 🚀 Phase 1: Single Cluster Team Platform

### Step 1.1: Documentation Review (10 minutes) 📚

**Recommended Reading:**

Please review the following documentation in the `docs/` folder:

- Platform architecture overview
- Security model documentation
- Team isolation concepts
- GitOps workflow

### Step 1.2: Deploy Core Infrastructure (20 minutes) ⚙️

**Deploy the main ML platform cluster:**

```bash
# Option 1: Fresh deployment
make deploy-tf-local

# Option 2: Clean existing and redeploy
make clean-local && make deploy-tf-local

# Option 3: Apply incremental changes
make init-tf-local && make apply-tf-local
```

**What gets created:**

- ✅ **Kind cluster** - Local Kubernetes development environment
- ✅ **Database** - PostgreSQL in dedicated namespace
- ✅ **Cache** - Redis for high-speed data caching
- ✅ **Storage** - MinIO with pre-created buckets
- ✅ **Networking** - Local path provisioner and services
- ✅ **Security** - TLS termination and audit logging

**Verification:**

```bash
# Verify cluster creation
kind get clusters
kubectl config use-context kind-data-platform-local

# Check core components
kubectl get pods -A
kubectl get namespaces
kubectl get services -A
kubectl get pvc -A

# Verify storage buckets
kubectl get jobs -A | grep create-bucket
```

> **📝 Note:** Team namespaces (app-ml-team, app-data-team, app-core-team) will be created by ArgoCD in the next step.

### Step 1.3: Deploy GitOps & Security (15 minutes) 🔐

**Deploy ArgoCD and security policies:**

```bash
# Deploy GitOps and application-level security
make deploy-argocd-local
```

**What gets created:**

- ✅ **ArgoCD** - GitOps continuous deployment
- ✅ **Team namespaces** - ml-team, data-team, core-team
- ✅ **Network policies** - Team isolation
- ✅ **Resource quotas** - CPU/memory limits per team
- ✅ **RBAC policies** - Role-based access control
- ✅ **Security middleware** - Rate limiting and headers

**Verification:**

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Verify team namespaces were created
kubectl get namespaces | grep app-.*-team

# Check security components
kubectl get networkpolicies -A
kubectl get resourcequota -A
kubectl get certificates -A
```

**Troubleshooting ArgoCD sync issues:**

```bash
# Debug application sync status
kubectl describe application security-policies -n argocd | grep -A 10 "Message:"

# Force sync if needed
kubectl patch application security-policies -n argocd --type merge \
  --patch '{"operation": {"sync": {}}}'
```

---

## 🧪 Phase 2: Testing & Validation

### Step 2.1: Run Comprehensive Tests (10 minutes) ✅

```bash
# Run all infrastructure tests
make test
```

### Step 2.2: Validate Labels & Compliance (5 minutes) 🏷️

```bash
# Check resource labeling compliance
./scripts/monitoring/check-resource-labels.sh

# Verify team isolation labels
kubectl get namespaces --show-labels
kubectl get nodes --show-labels

# Check performance events
kubectl get events -n data-platform-performance --sort-by=.metadata.creationTimestamp
```

### Step 2.3: Test Resource Quotas (10 minutes) 💾

```bash
# Check current quota usage
kubectl describe quota ml-team-quota -n app-ml-team
kubectl get resourcequota --all-namespaces

# Test quota enforcement
./scripts/security/test-resource-quotas.sh local
```

**Expected Results:**

- ✅ Small pods within quota should be allowed
- ❌ Pods exceeding quota should be blocked
- ✅ Multi-pod quota exhaustion should be prevented

### Step 2.4: Validate Security & RBAC (10 minutes) 🔒

```bash
# Run security isolation checks
./scripts/security/check-single-cluster-isolation.sh

# Test RBAC boundaries
kubectl auth can-i create pods \
    --as=ml-engineer@company.com \
    --as-group=ml-engineers \
    -n app-ml-team   # ✅ Should be YES

kubectl auth can-i create pods \
    --as=data-engineer@company.com \
    --as-group=data-engineers \
    -n app-ml-team   # ❌ Should be NO

# Test network policies
kubectl get networkpolicies --all-namespaces

# Verify TLS certificates
kubectl get certificates --all-namespaces
```

### Step 2.5: Monitor System Health (5 minutes) 📊

```bash
# Check basic monitoring
kubectl top nodes 2>/dev/null || echo "Metrics server not deployed"
kubectl top pods --all-namespaces | head -10 2>/dev/null

# Check monitoring CRDs
kubectl get servicemonitors --all-namespaces 2>/dev/null || echo "Prometheus CRDs not installed"
kubectl get prometheusrules --all-namespaces 2>/dev/null

# Test monitoring stack (if deployed)
if kubectl get pods -n monitoring &>/dev/null; then
    echo "🔍 Monitoring stack found - testing access..."
    
    # Port forward to monitoring services
    kubectl port-forward -n monitoring svc/prometheus-server 9090:9090 &
    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
    
    echo "🎯 Access URLs:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3000"
    echo ""
    echo "📈 Suggested Prometheus queries:"
    echo "  - sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)"
    echo "  - sum(container_memory_working_set_bytes) by (namespace) / 1024^3"
    echo "  - count(kube_pod_info) by (namespace)"
    
    sleep 5
    pkill -f "kubectl port-forward"
else
    echo "⚠️  Monitoring stack not deployed - using basic kubectl commands"
fi
```

---

## 🔧 Phase 3: Advanced Topics

### Provider Version Management

**Centralized Configuration:**

All provider versions are managed in `/infrastructure/terraform/versions/terraform-versions.yaml`:

```yaml
terraform_version: ">= 1.6.0"
provider_versions:
  aws: "5.95.0"
  kubernetes: "2.24.0"
  helm: "2.17.0"
  kind: "0.1.4"
```

**Version Management Commands:**

```bash
# Check current status
make version-status
make version-check-updates
make version-security-audit

# Update versions (edit yaml file first)
./infrastructure/scripts/generate-terraform-versions.sh
ls infrastructure/terraform/environments/*/versions.tf

# Apply updates per environment
make version-plan ENV=local
make update-versions-local
make init-tf-local && make apply-tf-local
```

### Adding New Modules

**Zero Configuration Required:**

```bash
# Create new module (inherits versions automatically)
mkdir infrastructure/terraform/modules/my-new-module

# No provider version configuration needed
# Versions automatically inherited from environment
```

### Troubleshooting Version Issues

**Lock File Problems:**

```bash
# Fix lock file inconsistencies
cd infrastructure/terraform/environments/local
rm -f .terraform.lock.hcl
rm -rf .terraform
terraform init --upgrade
```

**Version Conflicts:**

```bash
# Check for conflicts
make version-validate

# Update terraform-versions.yaml, then:
make init-tf-local
```

---

## 🎯 Learning Summary

### Architecture Understanding

**What You've Built:**

- ✅ **Single Cluster** with team isolation (not multi-cluster complexity)
- ✅ **Kubernetes-native security** (not service mesh overhead)
- ✅ **Resource quotas & RBAC** provide strong boundaries
- ✅ **Network policies** ensure team isolation
- ✅ **Proper labeling** enables cost tracking and governance

**Key Components:**

| Component          | Purpose                               | Location                        |
|--------------------|---------------------------------------|---------------------------------|
| **Team Isolation** | Resource quotas, namespace boundaries | `kubernetes/security/policies/` |
| **RBAC**           | Team-specific role-based access       | `kubernetes/security/rbac/`     |
| **Security**       | TLS, audit, network policies          | `kubernetes/security/`          |
| **Monitoring**     | Team dashboards and alerting          | `kubernetes/monitoring/`        |

### Essential Commands

```bash
# Deploy and manage infrastructure
make deploy-tf-local
make deploy-argocd-local
make test

# Security and compliance
./scripts/security/check-single-cluster-isolation.sh
./scripts/security/test-resource-quotas.sh local
kubectl auth can-i create pods --as=ml-engineer@company.com -n app-ml-team

# Monitoring and troubleshooting
kubectl get pods -l team=ml-engineering --all-namespaces
kubectl top nodes
kubectl get resourcequota --all-namespaces
```

### Next Steps for Development

1. **Deploy Applications** - Use team namespaces with proper resource constraints
2. **Implement Monitoring** - Team-specific dashboards and alerting
3. **Blue-Green Deployments** - Safe release strategies
4. **Scale Wisely** - Multi-cluster only when compliance requires it

---

## 🚨 Troubleshooting

### Common Issues & Solutions

#### Terraform Kind Provider Checksum Error

**Error:**
```
Error: Failed to install provider
Error while installing gigifokchiman/kind v0.1.0: the local package doesn't match checksums
```

**Solution:**
```bash
# Navigate to environment directory
cd infrastructure/terraform/environments/local

# Clean and reinitialize
rm -f .terraform.lock.hcl
rm -rf .terraform
terraform init --upgrade
```

#### Platform Deployment Failures

**Symptoms:** Pods not starting, services unavailable

**Solution:**
```bash
# Check cluster status
kind get clusters
kubectl get pods --all-namespaces

# Clean up and retry
helm uninstall <app-name> -n <namespace>
terraform destroy -auto-approve
kind delete cluster --name data-platform-local

# Retry deployment
make deploy-tf-local
```

#### Port Conflicts

**Error:** Port binding failures

**Solution:**
```bash
# Check what's using the port
lsof -i :8080

# Use different ports in configuration
# Or stop conflicting services
```

#### ArgoCD Sync Issues

**Symptoms:** Applications stuck in "OutOfSync" status

**Solution:**

```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# Force sync
kubectl patch application <app-name> -n argocd --type merge \
  --patch '{"operation": {"sync": {}}}'
```

### Getting Help

1. **Documentation** - Check `docs/` folder for detailed guides
2. **Scripts** - All deployment scripts have built-in help (`--help`)
3. **Team** - Share configurations for review
4. **Issues** - Report problems with detailed logs

---

## 🧹 Cleanup

### Option A: Standard Cleanup (Recommended)

```bash
# Exit Docker container if running
exit

# Clean up from local machine
cd infrastructure
make clean-tf-local

# Manual cleanup if needed
kind delete cluster --name data-platform-local
```

### Option B: Docker Cleanup

```bash
# From Docker container
make clean-tf-local

# If issues occur
docker exec -it $(docker ps -q --filter ancestor=ml-platform-tools) \
  bash -c "kind delete cluster --name data-platform-local --kubeconfig /dev/null"
```

### Complete Environment Reset

```bash
# Remove all Kind clusters
kind get clusters | xargs -I {} kind delete cluster --name {}

# Clean terraform state
cd infrastructure/terraform/environments/local
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*

# Clean Docker resources
docker system prune -f
```

---

## 🎉 Congratulations!

You've successfully completed the modern single-cluster platform experience!

**What You've Mastered:**

- ✅ **Single Cluster Team Isolation** - 80% of multi-cluster benefits, 20% of complexity
- ✅ **Kubernetes-Native Security** - Enterprise compliance without service mesh
- ✅ **Resource Quotas & RBAC** - Strong team boundaries and governance
- ✅ **Smart Labeling Strategy** - Cost tracking and resource management
- ✅ **GitOps Workflow** - Declarative, version-controlled deployments
- ✅ **Production Security** - TLS, audit, network policies, rate limiting

**You've made the smart choice: Simple, secure, scalable!** 🎯

---

*Welcome to the team! You now understand our modern infrastructure platform.*

**Time to build amazing applications!** 🚀
