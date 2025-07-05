# Module Update Guide

## Overview

This guide explains how to safely update open source Terraform modules while maintaining system stability and
organizational standards.

## 🎯 Update Strategy

### Release Types

| Update Type               | Risk Level | Testing Required   | Approval            |
|---------------------------|------------|--------------------|---------------------|
| **Patch** (1.0.0 → 1.0.1) | Low        | Dev environment    | Auto-approve        |
| **Minor** (1.0.0 → 1.1.0) | Medium     | Dev + Staging      | Team review         |
| **Major** (1.0.0 → 2.0.0) | High       | Full testing cycle | Architecture review |

### Version Pinning Strategy

```hcl
# Recommended version constraints
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"  # Allow patch updates only
  # version = "~> 20.0"  # Allow minor updates  
  # version = ">= 20.0, < 21.0"  # Explicit range
}
```

## 📋 Update Checklist

### Pre-Update Assessment

- [ ] **Review upstream CHANGELOG** for breaking changes
- [ ] **Check security advisories** and CVE fixes
- [ ] **Validate compatibility** with current Terraform version
- [ ] **Assess impact** on our wrapper modules
- [ ] **Plan rollback strategy** if needed

### Update Process

#### 1. Development Environment Testing

```bash
# Navigate to dev environment
cd environments/dev

# Backup current state
terraform plan -out=before.plan

# Update module versions
vim main.tf  # or terraform.tf

# Initialize with new versions
terraform init -upgrade

# Review changes
terraform plan -detailed-exitcode

# Apply if plan looks good
terraform apply

# Validate functionality
kubectl get nodes
kubectl get pods --all-namespaces
```

#### 2. Validation Testing

```bash
# Test cluster functionality
kubectl cluster-info
kubectl get nodes -o wide

# Test application deployments
kubectl apply -f test-deployment.yaml
kubectl get pods -w

# Test platform services
kubectl port-forward svc/postgres 5432:5432 &
psql -h localhost -p 5432 -U admin -d metadata

# Clean up test resources
kubectl delete -f test-deployment.yaml
```

#### 3. Staging Environment

```bash
cd environments/staging

# Apply same version updates
terraform init -upgrade
terraform plan
terraform apply

# Run integration tests
./scripts/run-integration-tests.sh

# Monitor for 24-48 hours
```

#### 4. Production Deployment

```bash
cd environments/prod

# Final review
terraform plan -out=prod.plan
# Share plan with team for review

# Apply during maintenance window
terraform apply prod.plan

# Monitor closely
kubectl get events --sort-by='.lastTimestamp'
```

## 🚨 Handling Breaking Changes

### Common Breaking Change Types

#### 1. Variable Rename/Removal

**Before**:

```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name = "my-cluster"
  subnets      = var.subnets  # ← Removed in v20
}
```

**After**:

```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name = "my-cluster" 
  subnet_ids   = var.subnets  # ← New name in v20
}
```

**Our Fix**:

```hcl
# In our wrapper module
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name = var.name
  subnet_ids   = var.subnet_ids  # Update our variable mapping
}
```

#### 2. Output Structure Changes

**Migration Strategy**:

```hcl
# Add compatibility layer in our wrapper
output "cluster_endpoint" {
  description = "Cluster endpoint"
  # Handle both old and new output structures
  value = try(
    module.eks.cluster_endpoint,           # New structure
    module.eks.cluster_primary_endpoint,   # Old structure  
    null
  )
}
```

#### 3. Resource Restructuring

**State Migration**:

```bash
# Move resources to new structure
terraform state mv 'module.eks.aws_eks_cluster.cluster[0]' 'module.eks.aws_eks_cluster.this[0]'

# Import new resources if needed
terraform import 'module.eks.aws_eks_addon.this["vpc-cni"]' my-cluster:vpc-cni
```

## 🔄 Automated Update Workflow

### GitHub Actions Example

```yaml
# .github/workflows/module-updates.yml
name: Module Updates

on:
  schedule:
    - cron: '0 9 * * MON'  # Weekly on Monday
  workflow_dispatch:

jobs:
  check-updates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Check for updates
        run: |
          cd environments/dev
          terraform init -upgrade
          terraform plan -detailed-exitcode || echo "Updates available"
          
      - name: Create PR if updates
        uses: peter-evans/create-pull-request@v4
        with:
          title: "Terraform module updates"
          body: |
            Automated module update check found new versions.
            
            Please review changes carefully before merging.
            
            Test checklist:
            - [ ] Dev environment tested
            - [ ] Breaking changes reviewed
            - [ ] Documentation updated
```

### Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "terraform"
    directory: "/infrastructure/terraform/environments/dev"
    schedule:
      interval: "weekly"
    reviewers:
      - "infrastructure-team"
    assignees:
      - "infrastructure-lead"
```

## 📊 Monitoring and Rollback

### Health Checks Post-Update

```bash
#!/bin/bash
# scripts/health-check.sh

echo "=== Cluster Health Check ==="
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running

echo "=== Resource Status ==="
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces

echo "=== Recent Events ==="
kubectl get events --sort-by='.lastTimestamp' | tail -20

echo "=== Platform Services ==="
# Test database connectivity
kubectl exec -n database deployment/postgres -- pg_isready

# Test cache connectivity  
kubectl exec -n cache deployment/redis -- redis-cli ping

# Test storage
kubectl exec -n storage deployment/minio -- mc ready local
```

### Rollback Procedure

```bash
#!/bin/bash
# scripts/rollback.sh

# 1. Revert to previous module versions
git checkout HEAD~1 -- environments/dev/main.tf

# 2. Re-initialize Terraform
cd environments/dev
terraform init -upgrade

# 3. Plan rollback
terraform plan -out=rollback.plan

# 4. Apply rollback
terraform apply rollback.plan

# 5. Verify system health
./scripts/health-check.sh
```

## 📅 Update Schedule

### Regular Maintenance Windows

| Environment    | Day      | Time (UTC)  | Duration |
|----------------|----------|-------------|----------|
| **Dev**        | Any day  | Any time    | 30 min   |
| **Staging**    | Tuesday  | 14:00-16:00 | 2 hours  |
| **Production** | Saturday | 02:00-06:00 | 4 hours  |

### Emergency Updates

**Security patches** can be applied outside maintenance windows with:

- Team lead approval
- Incident communication
- Rollback plan prepared
- Monitoring during update

## 🔍 Troubleshooting Updates

### Common Issues

#### Provider Version Conflicts

```bash
# Error: provider version mismatch
terraform init -upgrade
rm -rf .terraform.lock.hcl
terraform init
```

#### State Lock Issues

```bash
# Force unlock if safe
terraform force-unlock <lock-id>

# Or wait for automatic timeout
```

#### Resource Drift

```bash
# Refresh state to match reality
terraform refresh

# Plan to see differences
terraform plan

# Import missing resources
terraform import aws_eks_cluster.main my-cluster-name
```

### Debug Process

1. **Enable verbose logging**:
   ```bash
   export TF_LOG=DEBUG
   export TF_LOG_PATH=./terraform.log
   terraform plan
   ```

2. **Check provider compatibility**:
   ```bash
   terraform version
   terraform providers
   ```

3. **Validate configuration**:
   ```bash
   terraform validate
   terraform fmt -check -recursive
   ```

## 📚 Resources

### Change Tracking

- [terraform-aws-modules/eks releases](https://github.com/terraform-aws-modules/terraform-aws-eks/releases)
- [terraform-aws-modules/vpc releases](https://github.com/terraform-aws-modules/terraform-aws-vpc/releases)
- [terraform-aws-modules/rds releases](https://github.com/terraform-aws-modules/terraform-aws-rds/releases)

### Documentation

- [Terraform Module Versioning](https://www.terraform.io/docs/modules/sources.html#selecting-a-revision)
- [AWS Provider Changelog](https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md)
- [Kubernetes Provider Changelog](https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/CHANGELOG.md)

### Tools

- [terraform-docs](https://terraform-docs.io/) - Generate documentation
- [tflint](https://github.com/terraform-linters/tflint) - Terraform linter
- [checkov](https://www.checkov.io/) - Security scanning
- [terragrunt](https://terragrunt.gruntwork.io/) - DRY Terraform

---

**Last Updated**: January 2025  
**Owner**: Infrastructure Team  
**Review Cycle**: Monthly
