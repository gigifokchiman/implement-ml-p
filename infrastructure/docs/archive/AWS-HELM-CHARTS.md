# AWS Production Deployment with Helm Charts

## Why Helm Charts Instead of Direct Installation?

### ❌ **Direct Installation Problems**
```bash
# Direct kubectl apply or simple helm install
helm install aws-load-balancer-controller eks/aws-load-balancer-controller --set clusterName=my-cluster
```

**Issues:**
- No version pinning → unexpected updates
- No configuration management → scattered settings
- No rollback capability → manual recovery
- No GitOps compatibility → no automation
- No environment consistency → different configs

### ✅ **Production Helm Chart Approach**
```bash
# Production approach with values files
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --values ./values/aws-load-balancer-controller.yaml \
  --set clusterName=$CLUSTER_NAME \
  --wait --timeout 10m
```

**Benefits:**
- **Version Management**: Pin specific chart/image versions
- **Configuration Management**: Comprehensive values.yaml files
- **GitOps Ready**: Values files in source control
- **Environment Consistency**: Same chart, different values
- **Rollback Capability**: `helm rollback` for quick recovery
- **Production Features**: HA, monitoring, security, resource limits

## Implementation

### 🗂️ **File Structure**
```
infrastructure/cloud/aws/
├── Makefile                                    # Helm-based deployment
├── values/
│   ├── aws-load-balancer-controller.yaml      # ALB Controller production config
│   └── aws-ebs-csi-driver.yaml               # EBS CSI production config
└── scripts/
    └── setup-aws-prerequisites.sh             # IAM roles and service accounts
```

### ⚙️ **Production Configurations**

#### AWS Load Balancer Controller (`values/aws-load-balancer-controller.yaml`)
```yaml
# High Availability
replicaCount: 2

# Version Pinning
image:
  tag: v2.7.2

# Resource Management
resources:
  limits:
    cpu: 200m
    memory: 500Mi

# IAM Integration
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole

# Production Features
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Monitoring
metrics:
  enabled: true
```

#### EBS CSI Driver (`values/aws-ebs-csi-driver.yaml`)
```yaml
# Version Pinning (all components)
image:
  tag: v1.25.0
sidecars:
  provisioner:
    tag: v3.6.2

# Multiple Storage Classes
storageClasses:
  - name: ebs-gp3                    # Default fast storage
  - name: ebs-gp3-retain            # Persistent storage
  - name: ebs-io1-high-iops         # High performance

# Volume Snapshots
volumeSnapshotClasses:
  - name: ebs-vsc
    annotations:
      snapshot.storage.kubernetes.io/is-default-class: "true"
```

### 🔧 **Deployment Process**

#### 1. Prerequisites Setup
```bash
# Automated IAM setup
make setup-aws-prerequisites
```
Creates:
- IAM policies for ALB Controller and EBS CSI
- Service accounts with IAM role annotations
- Updates values files with account-specific ARNs

#### 2. Helm Chart Installation
```bash
# Production deployment
make deploy
```
Runs:
- `helm upgrade --install` with version pinning
- Uses production values files
- Waits for successful deployment
- Verifies components are running

#### 3. Verification
```bash
# Verify all components
make verify-aws-components
```

## Comparison: Direct vs Helm Chart

| Aspect | Direct Installation | Helm Chart Production |
|--------|-------------------|---------------------|
| **Version Control** | ❌ Latest/unstable | ✅ Pinned versions |
| **Configuration** | ❌ CLI flags only | ✅ Comprehensive values |
| **Rollbacks** | ❌ Manual recovery | ✅ `helm rollback` |
| **GitOps** | ❌ Not compatible | ✅ ArgoCD/Flux ready |
| **Environments** | ❌ Inconsistent | ✅ Same chart, different values |
| **Monitoring** | ❌ Basic/none | ✅ Prometheus metrics |
| **HA Setup** | ❌ Single replica | ✅ Multi-replica with PDB |
| **Resource Limits** | ❌ Defaults | ✅ Production tuned |
| **Security** | ❌ Minimal | ✅ IAM, RBAC, security contexts |

## Production Benefits

### 🏗️ **Infrastructure as Code**
- Values files in Git for full auditability
- Environment-specific configurations
- Automated deployment pipelines

### 🔄 **GitOps Integration**
```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aws-load-balancer-controller
spec:
  source:
    repoURL: https://aws.github.io/eks-charts
    chart: aws-load-balancer-controller
    targetRevision: 1.6.2  # Pinned version
    helm:
      valueFiles:
        - values/aws-load-balancer-controller.yaml
```

### 📊 **Monitoring & Observability**
- Prometheus metrics enabled by default
- Comprehensive health checks
- Pod disruption budgets for availability

### 🛡️ **Security & Compliance**
- IAM roles with least privilege
- Security contexts and pod security standards
- Network policies and RBAC

### 🚀 **Scalability & Performance**
- Multi-replica controllers for HA
- Resource limits and requests tuned for production
- Anti-affinity rules for node distribution

## Migration Guide

### From Direct Installation
1. **Backup current configuration**:
   ```bash
   kubectl get deployment aws-load-balancer-controller -n kube-system -o yaml > backup.yaml
   ```

2. **Uninstall direct installation**:
   ```bash
   kubectl delete deployment aws-load-balancer-controller -n kube-system
   ```

3. **Install via Helm**:
   ```bash
   make setup-aws-prerequisites
   make install-aws-load-balancer-controller
   ```

### Version Upgrade Process
1. **Update values file** with new version
2. **Test in staging** environment first
3. **Run upgrade**:
   ```bash
   helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
     --values ./values/aws-load-balancer-controller.yaml
   ```
4. **Verify deployment**:
   ```bash
   make verify-aws-components
   ```

## Best Practices

### 🎯 **Version Management**
- Pin chart versions in production
- Pin image tags for all components
- Test upgrades in staging first

### 📝 **Configuration Management**
- Use values files instead of `--set` flags
- Environment-specific values inheritance
- Document all configuration changes

### 🔍 **Monitoring**
- Enable Prometheus metrics
- Set up alerting for controller health
- Monitor resource usage and adjust limits

### 🛠️ **Maintenance**
- Regular security updates
- Performance monitoring and tuning
- Backup configurations before changes

This Helm chart approach provides the production-grade deployment pattern you need for reliable, scalable AWS infrastructure management.