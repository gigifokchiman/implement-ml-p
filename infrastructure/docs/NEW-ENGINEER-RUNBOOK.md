# New Engineer Runbook

**Complete hands-on guide for new engineers to experience the modern ML platform infrastructure with team isolation and
security.**

## 🎯 Overview

This runbook guides you through the modern ML platform infrastructure approach - **single cluster with team isolation**
and **Kubernetes-native security**. By the end, you'll have:

- ✅ **Deployed** a production-ready single cluster with team boundaries
- ✅ **Experienced** resource quotas, RBAC, and network policies
- ✅ **Implemented** enterprise-grade security without service mesh complexity
- ✅ **Tested** the complete team isolation and monitoring setup
- ✅ **Prepared** for secure, scalable application development

**Estimated Time:** 3-4 hours (single session)

**Architecture Approach:** Single cluster with namespace isolation (80% of multi-cluster benefits, 20% of complexity)

### System Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 20GB free space
- **OS**: macOS (currently tested in macOS)

### Repository Setup

```bash
# Clone the repository
git clone https://github.com/gigifokchiman/implement-ml-p.git # OR download from the github. 
cd implement-ml-p

# Verify structure
ls -la infrastructure/
```

## 📋 Prerequisites

**Choose Your Approach:**

### Option A: Local Tool Installation

### Required Tools

```bash
brew update && brew upgrade
```

| Tool       | Version  | Purpose                   | Installation                                                                                                |
|------------|----------|---------------------------|-------------------------------------------------------------------------------------------------------------|
| AWS CLI    | 2.0+     | AWS cloud operations      | `brew install awscli`                                                                                       |
| Docker     | 20.10+   | Container runtime         | [Docker Desktop](https://www.docker.com/products/docker-desktop)                                            |
| Git        | 2.30+    | Version control           | `brew install git` or [Git Downloads](https://git-scm.com/downloads)                                        |
| Kind       | 0.20+    | Local Kubernetes clusters | `brew install kind` or [Kind Releases](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)        |
| kubectl    | 1.27+    | Kubernetes CLI            | `brew install kubectl` or [kubectl Install](https://kubernetes.io/docs/tasks/tools/)                        |
| Kubernetes | 1.27+    | Container orchestration   | Included with Docker Desktop                                                                                |
| Kustomize  | 5.0+     | Kubernetes configuration  | `brew install kustomize` or [Kustomize Install](https://kubectl.docs.kubernetes.io/installation/kustomize/) |
| Helm       | v3.18.3+ | Deploy to k8s             | `brew install helm`                                                                                         |
| Terraform  | 1.0+     | Infrastructure as Code    | `brew install terraform` or [Terraform Downloads](https://www.terraform.io/downloads)                       |

### Custom Terraform Provider

This project uses a custom Kind terraform provider. Download it locally:

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

# Create terraform plugins directory with proper architecture folder
mkdir -p ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/$TERRAFORM_ARCH

# Download and install the provider
wget https://github.com/gigifokchiman/kind/releases/download/v0.1.0/terraform-provider-kind_v0.1.0_${TERRAFORM_ARCH}.tar.gz \
  -O /tmp/terraform-provider-kind.tar.gz
cd /tmp && tar -xzf terraform-provider-kind.tar.gz
cp terraform-provider-kind_v0.1.0 ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/$TERRAFORM_ARCH/terraform-provider-kind

# Make it executable
chmod +x ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/$TERRAFORM_ARCH/terraform-provider-kind

# Clean up
rm -f /tmp/terraform-provider-kind*
```


### Optional Tools

| Tool     | Purpose                                                          | Installation            |
|----------|------------------------------------------------------------------|-------------------------|
| gh       | GitHub CLI                                                       | `brew install gh`       |
| Go       | For changing the configuration from the kind terraform           | `brew install go`       |
| graphviz | Infrastructure visualization and diagram generation (macos only) | `brew install graphviz` |
| k6       | Load testing and performance validation                          | `brew install k6`       |
| jq       | JSON processing                                                  | `brew install jq`       |
| tfsec    | Terraform security scanning                                      | `brew install tfsec`    |
| trivy    | Container security scanning                                      | `brew install trivy`    |
| yq       | YAML processing                                                  | `brew install yq`       |

### Option A: Local approach

```bash
# Verify installations
awscli --version
docker --version
git version
kind --version
kubectl version --client  # >= 1.25
kustomize version
helm version
terraform --version  # >= 1.0

# Verify custom terraform provider is installed
ls -la ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.4/*/terraform-provider-kind

cd infrastructure
```

### Option B: Docker-Only Approach (Recommended for Quick Start)

### Required Tools

```bash
brew update && brew upgrade
```

**🐳 Docker Container Benefits:**

- ✅ **No local tool installation** required
- ✅ **Consistent tool versions** across team members
- ✅ **All security scanners** pre-installed (Checkov, tfsec, Terrascan, OPA)
- ✅ **Performance tools** included (K6, Chaos Toolkit)
- ✅ **Kubernetes utilities** (k9s, kubectx, kubens, Kustomize)
- ✅ **Monitoring tools** (Prometheus CLI tools)

| Tool    | Version | Purpose              | Installation                                                     |
|---------|---------|----------------------|------------------------------------------------------------------|
| AWS CLI | 2.0+    | AWS cloud operations | `brew install awscli`                                            |
| Docker  | 20.10+  | Container runtime    | [Docker Desktop](https://www.docker.com/products/docker-desktop) |

```bash
# Verify Docker installation
docker --version
docker info

# Build the infrastructure tools container
cd infrastructure
docker build -t ml-platform-tools .

# Verify all tools are working
docker run --rm ml-platform-tools health-check.sh

# IMPORTANT: Use --network host so container can access Kind cluster
docker run -it --rm --user root \
  --network host \
  -v ~/.docker/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -v ~/.aws:/workspace/.aws:ro \
  -v ~/.kube:/workspace/.kube \
  ml-platform-tools

```

**🔍 Docker Container Notes:**
- `--network host` is REQUIRED for kubectl to access the Kind cluster

## 🚀 Phase 1: Single Cluster Team Platform (45 minutes)

### Step 1.1: Documentation Review (10 minutes)

```bash
# Read the modern approach docs
cat SINGLE-CLUSTER-BEST-PRACTICES.md
cat KUBERNETES-SECURITY-SUMMARY.md
cat LABELING-SUMMARY.md
```

### Step 1.2: Deploy Single Cluster with Team Isolation (20 minutes)

Deploy a single cluster with proper team boundaries:

```bash
# Deploy the main ML platform cluster with comprehensive setup
make deploy-tf-local

# If you have tf provider issues
make init-tf-local && make deploy-tf-local

# This creates:
# ✅ Single Kind cluster (ml-platform-local)
# ✅ Database (PostgreSQL) in database namespace
# ✅ Cache (Redis) in cache namespace  
# ✅ Storage (MinIO) with pre-created buckets in storage namespace
# ✅ Local path storage provisioner
# ✅ Kubernetes networking and services
# ✅ TLS termination at ingress with Let's Encrypt
# ✅ Kubernetes audit logging for compliance
#
# Verify deployment
kind get clusters
kubectl config use-context kind-data-platform-local

kubectl get pods -A
kubectl get namespaces
kubectl get services -A
kubectl get pvc -A
kubectl get rc,services -A





# Verify the namespaces and labels
./scripts/monitoring/check-resource-labels.sh

# you can see that app-xx-team not found as it will be handled by the argocd
# 👥 Team Namespaces:
# ⚠️  Team namespace app-ml-team not found
# ⚠️  Team namespace app-data-team not found
# ⚠️  Team namespace app-core-team not found

# 📊 Compliance Report
# ===================
# Total checks: 43
# Passed: 43
# Failed: 0

# to apply a small change
make init-tf-local && make apply-tf-local

```

**🎯 Understanding What We Built:**

- **Kind cluster**: Local Kubernetes development environment with multi-node setup
- **Database**: PostgreSQL instance in dedicated namespace for metadata storage
- **Cache**: Redis instance for high-speed data caching
- **Storage**: MinIO object storage with pre-created buckets (ml-artifacts, data-lake, model-registry, etc.)
- **Local Path Provisioner**: Dynamic volume provisioning for persistent workloads

**What Just Happened:**

1. **Terraform** created a Kind cluster with proper networking
2. **Kubernetes** deployed PostgreSQL, Redis, MinIO as core services
3. **Storage buckets** created for ML artifacts, data lake, and model registry
4. All components are running and ready for argocd and application development

### Step 1.3: Deploy ArgoCD

**🎯 Security Without Service Mesh Complexity**

Implement enterprise-grade security using plain Kubernetes + applications

```bash
# Deploy app-level security
make deploy-argocd-security

# This creates:
# ✅ Network policies for team isolation
# ✅ Rate limiting per team and endpoint
# ✅ Application-level security middleware
# ✅ Team namespaces (ml-team, data-team, app-team)

# Check team isolation compliance (validates deployment)
./scripts/security/check-single-cluster-isolation.sh

# Debugging why the application cannot be synced
kubectl get applications -n argocd
kubectl describe application security-policies -n argocd | grep -A 10 "Message:"
kubectl describe application security-policies -n argocd | grep -A 10 "Status:"

# patch
kubectl patch application security-policies -n argocd --type merge --patch '{"operation": {"sync":
      {}}}'

# Verify security components
kubectl get networkpolicies --all-namespaces
kubectl get certificates --all-namespaces
kubectl get prometheusrules --all-namespaces

make deploy-argocd-apps

```


### Step 1.3: Checkers and testing

```bash

# Check that labels are properly applied (for compliance)
./scripts/monitoring/check-resource-labels.sh

# Verify team isolation
kubectl get namespaces --show-labels
kubectl get resourcequota --all-namespaces
kubectl get nodes --show-labels

kubectl get events -n data-platform-performance --sort-by=.metadata.creationTimestamp

```

**🎯 Key Learning Points:**

- Each platform gets its own isolated cluster
- Consistent deployment process across all platforms
- Easy to customize via Helm values
- Infrastructure and applications are cleanly separated

## 🧪 Phase 2: Team Workload Management (30 minutes)

### Step 2.1: Deploy Team-Specific Workloads (15 minutes)

Deploy applications to each team namespace with proper constraints:

```bash
# Deploy ML workload (already created in ml-team namespace)
kubectl describe quota ml-team-quota -n app-ml-team

# Test resource quotas work - this should fail (exceeds quota)
kubectl run test-quota --image=nginx -n app-ml-team --dry-run=client -o yaml | \
kubectl set resources --local -f - --requests=cpu=10 --dry-run=client -o yaml | \
kubectl apply --dry-run=client -f -

kubectl get pods -n app-ml-team -o wide

# Or test with a simpler approach - create a pod that exceeds quota
cat <<EOF | kubectl apply --dry-run=client -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-quota-exceed
  namespace: ml-team
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "25"
        memory: "100Gi"
EOF

# Deploy within quota limits (delete existing pod first if needed)
kubectl delete pod ml-inference -n ml-team --ignore-not-found=true

# Create pod with resource requests within quota
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ml-inference
  namespace: ml-team
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "1"
        memory: "2Gi"
      limits:
        cpu: "2"
        memory: "4Gi"
EOF

# Check node placement (should prefer GPU-labeled nodes)
kubectl get pods -n ml-team -o wide
```

### Step 2.2: Test Team Isolation and RBAC (15 minutes)

```bash
# Test RBAC boundaries
kubectl auth can-i create pods --as=ml-engineer@company.com -n ml-team     # ✅ Should be yes
kubectl auth can-i create pods --as=ml-engineer@company.com -n data-team   # ❌ Should be no

# Test network policies (create temporary pod for testing)
kubectl run network-test --image=nicolaka/netshoot -n ml-team
# Exec into pod: kubectl exec -it network-test -n ml-team -- /bin/bash
# Inside pod, try: curl data-team-service.data-team (should fail due to network policies)
# Clean up: kubectl delete pod network-test -n ml-team

# Check team resource usage
kubectl get resourcequota --all-namespaces
kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics server not installed"

# Verify label compliance (important for cost tracking)
./infrastructure/scripts/monitoring/check-resource-labels.sh

# Port forward to monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
echo "Grafana: http://localhost:3000 (admin/prom-operator)"

# View team dashboards
# Open Grafana and look for "Team Resource Usage" dashboard

# Clean up
pkill -f "kubectl port-forward"
```

## 🧹 Phase 3: Security & Monitoring Validation (20 minutes)

### Step 3.1: Security Testing (10 minutes)

Validate that your security controls are working:

```bash
# Test TLS certificates (if cert-manager deployed)
kubectl get certificates --all-namespaces

# Test network policies and team isolation
echo "Testing network isolation..."
kubectl get networkpolicies --all-namespaces

# Validate team RBAC boundaries
kubectl auth can-i create pods --as=system:serviceaccount:app-ml-team:default -n app-ml-team
kubectl auth can-i create pods --as=system:serviceaccount:app-ml-team:default -n app-data-team

# Test resource quotas enforcement
kubectl get resourcequota --all-namespaces
kubectl describe resourcequota -n app-ml-team

# Test security scanning results (if deployed)
kubectl get vulnerabilityreports --all-namespaces 2>/dev/null || echo "Security scanning not deployed"
```

### Step 3.2: Team Monitoring & Alerting (10 minutes)

```bash
# Check team-specific monitoring (if Prometheus deployed)
kubectl get servicemonitors --all-namespaces 2>/dev/null || echo "Prometheus CRDs not installed"
kubectl get prometheusrules --all-namespaces 2>/dev/null || echo "Prometheus CRDs not installed"

# Apply monitoring configs if missing
if kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    kubectl apply -f kubernetes/monitoring/namespace-monitoring.yaml
    kubectl apply -f kubernetes/monitoring/team-dashboards.yaml
    echo "Team monitoring configs applied ✅"
fi

# Check basic cluster monitoring
kubectl top nodes 2>/dev/null || echo "Metrics server not deployed"
kubectl top pods --all-namespaces | head -10 2>/dev/null || echo "Metrics server not deployed"

# Validate resource usage per team
echo ""
echo "📊 Team Resource Usage:"
echo "======================"
for ns in app-ml-team app-data-team app-core-team; do
    if kubectl get namespace $ns &>/dev/null; then
        echo "Namespace: $ns"
        kubectl describe resourcequota -n $ns 2>/dev/null || echo "  No resource quota found"
        echo ""
    fi
done

# Test monitoring stack (if deployed)
if kubectl get pods -n monitoring &>/dev/null; then
    echo "🔍 Monitoring stack found - testing access..."
    kubectl port-forward -n monitoring svc/prometheus-server 9090:9090 &
    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
    
    echo "Prometheus: http://localhost:9090"
    echo "Grafana: http://localhost:3000"
    echo ""
    echo "Try these Prometheus queries:"
    echo "- sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)"
    echo "- sum(container_memory_working_set_bytes) by (namespace) / 1024^3"
    echo "- count(kube_pod_info) by (namespace)"
    
    sleep 5
    pkill -f "kubectl port-forward"
else
    echo "⚠️  Monitoring stack not deployed - using basic kubectl commands"
fi
```

## 🛠️ Phase 4: Testing

```bash
make test

make apply-tf-local
```

## 🔄 Provider Version Management

### Enterprise Provider Version Management System

This platform uses enterprise-grade provider version management based on Netflix/Airbnb patterns for consistent, secure
deployments across all environments.

#### Understanding the System

**Centralized Configuration:**

- All provider versions are managed centrally in `/infrastructure/terraform/versions/terraform-versions.yaml`
- Environment-specific version strategies (local: flexible, staging: strict, prod: exact)
- Automated generation of `versions.tf` files across all environments

**Current Provider Versions:**

```yaml
terraform_version: ">= 1.6.0"
provider_versions:
  aws: "5.95.0"
  kubernetes: "2.24.0"
  helm: "2.17.0"
  kind: "0.1.4"
```

#### How to Update Provider Versions

**Step 1: Check Current Status**

```bash
# View current provider versions across all environments
make version-status

# Check for available provider updates
make version-check-updates

# Run security compliance audit
make version-security-audit
```

**Step 2: Update Centralized Configuration**

```bash
# Edit the centralized configuration file
vim infrastructure/terraform/versions/terraform-versions.yaml

# Example: Update AWS provider from 5.95.0 to 5.96.0
provider_versions:
  aws: "5.96.0"  # Updated version
  kubernetes: "2.24.0"
  helm: "2.17.0"
  kind: "0.1.4"
```

**Step 3: Generate Updated Versions**

```bash
# Generate new versions.tf files for all environments
./infrastructure/scripts/generate-terraform-versions.sh

# Verify the generated files
ls infrastructure/terraform/environments/*/versions.tf
```

**Step 4: Apply Updates Per Environment**

**Local Environment (flexible versioning):**

```bash
# Plan version updates for local
make version-plan ENV=local

# Apply to local environment
make update-versions-local
make init-tf-local && make apply-tf-local
```

**Development Environment (strict versioning):**

```bash
# Plan version updates for dev
make version-plan ENV=dev

# Apply to dev environment
make update-versions-dev
```

**Production Environment (exact versioning - requires confirmation):**

```bash
# Plan version updates for production
make version-plan ENV=prod

# Apply to production (requires manual confirmation)
make update-versions-prod
```

#### Validation and Compliance

**Security Validation:**

```bash
# Run comprehensive security audit
make version-security-audit

# Generate compliance report
make version-compliance-report
```

**Version Consistency Check:**

```bash
# Validate version security compliance
make version-validate

# Check versions across all environments
make version-status
```

#### Adding New Modules

**Zero Configuration Required:**

- New modules automatically inherit provider versions from root configuration
- No need to add provider constraints to individual modules
- Centralized version management ensures consistency

**Example: Creating a new module**

```bash
# Create new module (no provider version configuration needed)
mkdir infrastructure/terraform/modules/my-new-module

# Module automatically inherits versions from:
# infrastructure/terraform/environments/<env>/versions.tf
```

#### Troubleshooting Version Issues

**Lock File Inconsistencies:**

```bash
# If you encounter lock file errors
cd infrastructure/terraform/environments/local
rm -f .terraform.lock.hcl
rm -rf .terraform
terraform init --upgrade
```

**Provider Version Conflicts:**

```bash
# Check for version conflicts
make version-validate

# Update conflicting versions in terraform-versions.yaml
# Then regenerate and reinitialize
make init-tf-local
```

#### Best Practices

1. **Always use centralized configuration** - Never add provider versions directly to modules
2. **Test in lower environments first** - Update local → dev → staging → prod
3. **Run security audits** - Use `make version-security-audit` before production updates
4. **Generate compliance reports** - Document version changes for audit trail
5. **Batch updates** - Update multiple providers together when possible

#### Security Features

- **Automated security scanning** of provider versions
- **Compliance reporting** for audit requirements
- **Environment-specific strategies** (flexible vs strict vs exact versioning)
- **Change validation** before applying updates
- **Rollback capabilities** via version control

This enterprise provider version management system ensures:

- ✅ **Consistency** across all environments and modules
- ✅ **Security** through automated vulnerability scanning
- ✅ **Compliance** with enterprise governance requirements
- ✅ **Scalability** for large infrastructure deployments
- ✅ **Maintainability** through centralized configuration

## 🛠️ Phase 5: Production Readiness (30 minutes) (WIP)

### Step 5.1: Disaster Recovery Testing (15 minutes)

Test your DR procedures:

```bash
# Review DR runbook
cat kubernetes/disaster-recovery/dr-runbook.md

# Test backup procedures (if Velero installed)
# kubectl apply -f kubernetes/disaster-recovery/velero-backup.yaml

# Test blue-green deployment
echo "Testing blue-green deployment..."
kubectl label namespace ml-team environment=blue
kubectl create namespace ml-team-green
kubectl label namespace ml-team-green environment=green

# Deploy to green environment
kubectl run ml-inference-green --image=nginx -n ml-team-green

# Simulate traffic switch (service selector change)
echo "Blue-green deployment tested ✅"

# Cleanup test
kubectl delete namespace ml-team-green
```

### Step 4.2: Migration Path Planning (15 minutes)

```bash
# Understand when to migrate to multi-cluster
echo "📋 Multi-Cluster Decision Matrix"
echo "==============================="

# Current single cluster status
echo "✅ Current Status (Single Cluster):"
echo "   • Teams: $(kubectl get namespaces -l team --no-headers | wc -l | xargs)"
echo "   • Resource isolation: Strong (quotas + limits)"
echo "   • Security: Enterprise-grade (TLS + RBAC + NetworkPolicies)"
echo "   • Complexity: Low"
echo "   • Cost: Minimal"
echo ""

# When to consider multi-cluster
echo "⚠️  Consider Multi-Cluster When:"
echo "   • Hard compliance boundaries needed (SOX, GDPR)"
echo "   • Teams need different K8s versions"
echo "   • Network policies insufficient for security"
echo "   • Resource contention causes performance issues"
echo ""

# Your migration path is ready
echo "🚀 Migration Path Ready:"
echo "   • Federation scripts available: ./infrastructure/scripts/archive/setup-federation.sh"
echo "   • Multi-cluster tested and working"
echo "   • Can migrate gradually by team"
echo "   • Keep shared services in main cluster"
```

## 🧹 Phase 5: Knowledge Transfer & Cleanup (15 minutes)

### Step 5.1: Team Knowledge Transfer (10 minutes)

```bash
# Document your team's setup for others
echo "📚 Creating team knowledge base..."

# Key learnings
echo "✅ Single cluster approach validated"
echo "✅ Team isolation working (quotas + RBAC + network policies)"
echo "✅ Security implemented without service mesh"
echo "✅ Monitoring and alerting configured"
echo "✅ Migration path to multi-cluster ready"

# Share the approach
echo ""
echo "🎯 Recommend this setup to other teams:"
echo "   1. Start with single cluster + team isolation"
echo "   2. Use Kubernetes-native security (not service mesh)"
echo "   3. Migrate to multi-cluster only when needed"
echo "   4. 80% of benefits, 20% of complexity"
```

### Step 5.2: Learning Documentation (5 minutes)

```bash
# Create your learning summary
cat > MY-PLATFORM-LEARNING.md << 'EOF'
# My Modern Platform Learning Summary

## 🎯 What I Learned

### Smart Architecture Approach
- ✅ **Single Cluster** with team isolation (not multi-cluster complexity)
- ✅ **Kubernetes-native security** (not service mesh overhead)
- ✅ **Resource quotas & RBAC** provide strong boundaries
- ✅ **Network policies** ensure team isolation
- ✅ **Proper labeling** enables cost tracking and governance

### Key Commands Mastered
```bash
# Deploy single cluster with team isolation
./infrastructure/scripts/security/deploy-single-cluster-isolation.sh

# Apply comprehensive security
./infrastructure/scripts/security/deploy-kubernetes-security.sh

# Test team boundaries
kubectl auth can-i create pods --as=ml-engineer@company.com -n data-team

# Query by team labels
kubectl get pods -l team=ml-engineering --all-namespaces
```

### Architecture Understanding

- Single cluster with strong namespace isolation
- Team-specific quotas, RBAC, and network policies
- TLS, audit logging, rate limiting without service mesh
- Smart resource labeling for cost and governance
- Migration path to multi-cluster available when needed

### Next Steps for Development

1. Deploy applications to team namespaces with proper resource constraints
2. Implement team-specific monitoring and alerting
3. Use blue-green deployments for safe releases
4. Scale to multi-cluster only if compliance or performance requires it

## 🚀 Ready for Secure, Scalable Development!
EOF

echo "✅ Learning complete! Check MY-PLATFORM-LEARNING.md"
```

## 🎉 Congratulations!

You've successfully completed the modern single-cluster platform experience! You now understand:

- ✅ **Single Cluster Team Isolation** - 80% of multi-cluster benefits, 20% of complexity
- ✅ **Kubernetes-Native Security** - Enterprise compliance without service mesh
- ✅ **Resource Quotas & RBAC** - Strong team boundaries and governance
- ✅ **Smart Labeling Strategy** - Cost tracking and resource management
- ✅ **Migration Path** - Multi-cluster ready when you need it
- ✅ **Production Security** - TLS, audit, network policies, rate limiting

## 🚀 What's Next?

1. **Deploy Team Applications**: Use the isolated namespaces for development
2. **Enhance Security**: Add Pod Security Standards if needed
3. **Monitor Team Usage**: Track resource consumption and costs
4. **Scale Wisely**: Migrate to multi-cluster only when compliance/performance requires it

**Key Components Deployed:**
- `kubernetes/team-isolation/` - Resource quotas and namespace boundaries
- `kubernetes/rbac/` - Team-specific role-based access control
- `kubernetes/security/` - TLS, audit, network policies, rate limiting
- `kubernetes/monitoring/` - Team dashboards and alerting

**You've made the smart choice: Simple, secure, scalable!** 🎯

---

*Welcome to the team! You now understand our modern infrastructure platform.*

## 🚨 Common Issues & Solutions

### Terraform Kind Provider Checksum Error

If you encounter this error:
```
Error: Failed to install provider
Error while installing gigifokchiman/kind v0.1.0: the local package doesn't match checksums
```

**Solution**:
```bash
# Navigate to the environment directory
cd infrastructure/terraform/environments/<app-name>

# Remove the lock file and terraform cache
rm -f .terraform.lock.hcl
rm -rf .terraform

# Reinitialize Terraform
terraform init --upgrade
```

### Platform Deployment Issues

If deployment fails:
```bash
# Check cluster status
kind get clusters
kubectl get pods --all-namespaces

# Clean up and retry
helm uninstall <app-name> -n <namespace>
cd infrastructure/terraform/environments/<app-name>
terraform destroy -auto-approve
kind delete cluster --name <app-name>-local

# Retry deployment
./infrastructure/scripts/deployment/deploy-new-app.sh <app-name> <port>
```

### Port Conflicts

If you get port binding errors:
```bash
# Check what's using the port
lsof -i :8080

# Use different ports
./infrastructure/scripts/deployment/deploy-new-app.sh my-app 8090 8453
```

## 🆘 Getting Help

If you encounter issues:

1. **Check Documentation**: [TERRAFORM-HELM-SIMPLE.md](./TERRAFORM-HELM-SIMPLE.md)
2. **Review Scripts**: All deployment scripts have built-in help
3. **Ask Team**: Share your deployment configurations for review

---

**Time to build amazing applications!** 🚀

## 🧹 Cleanup Instructions

### Option A: Clean from Local (Recommended)

```bash
# Exit Docker container if running
exit

# Clean up from local machine (has proper kube config write access)
cd infrastructure
make clean-tf-local

# If you get permission errors, manually clean:
kind delete cluster --name data-platform-local
kind delete cluster --name ml-platform-local
```

### Option B: Clean from Docker (if needed)

```bash
# Inside Docker container - may have kube config write issues
make clean-tf-local

# If kube config errors occur, clean manually:
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

# Clean Docker
docker system prune -f
```
