# Terraform vs ArgoCD: Governance & Management Strategy

## Overview

This document outlines the separation of concerns between Terraform and ArgoCD for platform governance.

## Separation Principle

### Terraform (Platform Layer)

**Lifecycle**: Long-lived, stable infrastructure
**Change Frequency**: Low (weekly/monthly)
**Approval**: Platform team only
**Examples**:

- EKS/Kind cluster provisioning
- VPC, subnets, security groups
- IAM roles and policies
- Storage classes
- ArgoCD bootstrap
- Cert-manager, Ingress controller

### ArgoCD (Application Layer)

**Lifecycle**: Short-lived, dynamic workloads
**Change Frequency**: High (daily/hourly)
**Approval**: Dev teams with guardrails
**Examples**:

- Application deployments
- Service configurations
- Security scanning tools
- Monitoring stack
- Team namespaces
- ConfigMaps/Secrets

## Governance Benefits

### 1. **Risk Management**

```yaml
# Terraform - High Risk, Low Frequency
- Changes can break entire cluster
- Requires senior approval
- Full testing required

# ArgoCD - Lower Risk, High Frequency
- Changes isolated to namespaces
- Self-service with guardrails
- Progressive rollouts
```

### 2. **Access Control**

```yaml
# Terraform
- Platform Team: Full access
- Dev Teams: Read-only
- Security: Audit access

# ArgoCD
- Platform Team: Admin
- Dev Teams: Namespace admin
- Security: Read + specific policies
```

### 3. **Compliance & Audit**

```yaml
# Terraform State
- Centralized state management
- State locking
- Versioned backends
- Change history

# ArgoCD Git
- Every change tracked in Git
- PR approval required
- Automated compliance checks
- GitOps audit trail
```

## Best Practices

### 1. **Platform Resources (Terraform)**

```hcl
# ✅ Good - Platform concerns
module "cluster" {
  source = "./modules/platform/cluster"
  # Stable, infrequent changes
}

module "networking" {
  source = "./modules/platform/networking"
  # Core infrastructure
}

# ❌ Bad - Application concerns
resource "kubernetes_deployment" "app" {
  # Should be in ArgoCD
}
```

### 2. **Application Resources (ArgoCD)**

```yaml
# ✅ Good - Application concerns
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-model-server
  namespace: ml-team

# ❌ Bad - Platform concerns  
apiVersion: storage.k8s.io/v1
kind: StorageClass
# Should be in Terraform
```

### 3. **Gray Areas - Security Tools**

Security scanning can go either way:

**Option A: Terraform** (Your initial approach)

- ✅ Enforced across all clusters
- ✅ Cannot be disabled by teams
- ❌ Namespace dependency issues
- ❌ Harder to update

**Option B: ArgoCD** (Recommended)

- ✅ Easy updates
- ✅ Can scan dynamic namespaces
- ✅ Per-environment configs
- ❌ Teams could potentially disable

**Solution**: Terraform creates namespace + RBAC, ArgoCD deploys tools

## Implementation Guidelines

### 1. **Bootstrap Order**

```bash
1. Terraform: Create cluster, ArgoCD, core services
2. ArgoCD: Deploy platform apps (security, monitoring)
3. ArgoCD: Deploy team namespaces
4. ArgoCD: Deploy team applications
```

### 2. **Change Management**

```yaml
Terraform Changes:
  - Require PR approval from 2 platform engineers
  - Run in maintenance window
  - Full rollback plan required

ArgoCD Changes:
  - Require PR approval from 1 team member
  - Can deploy anytime
  - Automatic rollback on failure
```

### 3. **Emergency Procedures**

```yaml
Platform Issue:
  - Use Terraform break-glass access
  - Direct kubectl for emergency fixes
  - Document all manual changes

Application Issue:
  - Use ArgoCD rollback
  - Scale to zero if needed
  - Dev team owns resolution
```

## Metrics for Success

1. **Deployment Velocity**
    - App deployments: Multiple per day ✅
    - Platform changes: Weekly/monthly ✅

2. **Incident Response**
    - App issues: Dev team responds < 15 min
    - Platform issues: Platform team responds < 5 min

3. **Compliance**
    - 100% changes tracked in Git
    - No manual kubectl changes in prod
    - All changes have approval trail

## Conclusion

Your separation approach is **correct** and aligns with:

- Netflix's platform approach
- Spotify's golden path
- Google's SRE practices

The key is maintaining discipline about what belongs where.
