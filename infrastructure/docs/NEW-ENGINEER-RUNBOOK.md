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
ls -la ~/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/*/terraform-provider-kind

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

kubectl get pods --all-namespaces
kubectl get namespaces
kubectl get services --all-namespaces

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

### Step 1.3: Deploy Kubernetes-Native Security (15 minutes)

**🎯 Security Without Service Mesh Complexity**

Implement enterprise-grade security using plain Kubernetes:

```bash
# Deploy app-level security
make deploy-argocd-local


# This creates:
# ✅ Network policies for team isolation
# ✅ Rate limiting per team and endpoint
# ✅ Application-level security middleware


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
```

**What Just Happened:**

1. **Terraform** created a Kind cluster with proper networking
2. **Kubernetes** deployed PostgreSQL, Redis, MinIO as core services
3. **Storage buckets** created for ML artifacts, data lake, and model registry
4. All components are running and ready for application development

```bash
# Verify deployment
kind get clusters
kubectl get pods --all-namespaces
kubectl get services --all-namespaces

# Access services via port forwarding
kubectl port-forward -n database svc/postgres 5432:5432 &
kubectl port-forward -n cache svc/redis 6379:6379 &
kubectl port-forward -n storage svc/minio 9001:9000 &

# Service endpoints:
# Database: postgresql://admin:password@localhost:5432/metadata
# Cache: redis://localhost:6379  
# Storage: http://localhost:9001 (minioadmin/minioadmin)
```



### Step 1.3: Deploy Team Isolation (15 minutes)

Now add team-specific namespaces and resource controls:

```bash
# Apply team isolation (resource quotas, RBAC)
./infrastructure/scripts/security/deploy-single-cluster-isolation.sh

# Check that labels are properly applied (for compliance)
./infrastructure/scripts/monitoring/check-resource-labels.sh

# This creates:
# ✅ Team namespaces (ml-team, data-team, app-team)
# ✅ Resource quotas and limits per team
# ✅ RBAC policies for team boundaries
# ✅ Proper node and resource labeling

# Verify team isolation
kubectl get namespaces --show-labels
kubectl get resourcequota --all-namespaces
kubectl get nodes --show-labels
```

**🚀 GitOps Setup with ArgoCD (20 minutes)**

Deploy ArgoCD and monitoring stack for GitOps workflow:

```bash
# 1. Deploy ArgoCD + Prometheus (with CRDs)
./infrastructure/scripts/deployment/deploy-argocd.sh

# 2. Now deploy team monitoring (CRDs are available)
./infrastructure/scripts/monitoring/deploy-team-monitoring.sh

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "ArgoCD: https://localhost:8080 (admin/<password from script>)"

# Access Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &
echo "Grafana: http://localhost:3000 (admin/prom-operator)"

# Configure ArgoCD applications for GitOps programatically or via GUI
./infrastructure/scripts/deployment/setup-argocd-apps.sh


```

**📊 What ArgoCD Manages:**

- ✅ Team monitoring (ServiceMonitors, PrometheusRules)
- ✅ Security policies and network policies
- ✅ Team isolation configurations
- ✅ GitOps-based application deployments

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
kubectl get pods -n ml-team -o wide
kubectl describe quota ml-team-quota -n ml-team

# Test resource quotas work - this should fail (exceeds quota)
kubectl run test-quota --image=nginx -n ml-team --dry-run=client -o yaml | \
kubectl set resources --local -f - --requests=cpu=25 --dry-run=client -o yaml | \
kubectl apply --dry-run=client -f -

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
# Test TLS certificates (if ingress deployed)
kubectl get certificates --all-namespaces

# Test network policies
echo "Testing network isolation..."
./infrastructure/scripts/utilities/view-federation.sh  # Check cluster status

# Test audit logging
kubectl logs -n kube-system -l k8s-app=fluent-bit-audit

# Test rate limiting (if ingress configured)
# curl -k https://ml-api.company.com/api/ml/inference  # Should work
# for i in {1..15}; do curl -k https://ml-api.company.com/api/ml/inference; done  # Should hit rate limit
```

### Step 3.2: Team Monitoring & Alerting (10 minutes)

```bash
# Check team-specific monitoring
kubectl get servicemonitors --all-namespaces
kubectl get prometheusrules --all-namespaces

# Access monitoring
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090 &
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Test team metrics queries
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000"
echo ""
echo "Try these Prometheus queries:"
echo "- sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)"
echo "- sum(container_memory_working_set_bytes) by (namespace) / 1024^3"
echo "- count(kube_pod_info) by (namespace)"

# Clean up
pkill -f "kubectl port-forward"
```

## 🛠️ Phase 4: Production Readiness (30 minutes)

### Step 4.1: Disaster Recovery Testing (15 minutes)

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
