# Migration Guide: From Inline to Modular Architecture

## Overview

This guide explains how to migrate from inline Terraform configurations to our new modular wrapper architecture,
allowing you to leverage open source modules while maintaining organizational consistency.

## 🎯 Migration Benefits

**Before (Inline Configuration):**

```hcl
# All resources defined directly in environment
resource "aws_eks_cluster" "main" {
  name     = "my-cluster"
  role_arn = aws_iam_role.cluster.arn
  # ... 50+ lines of configuration
}

resource "aws_eks_node_group" "main" {
  # ... 30+ lines of configuration
}

resource "aws_iam_role" "cluster" {
  # ... IAM configuration
}
# ... many more resources
```

**After (Modular Wrapper):**

```hcl
# Single module call with best practices built-in
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  
  name        = "my-cluster"
  environment = "dev"
  use_aws     = true
  
  node_groups = var.node_groups
  tags        = var.tags
}
```

## 🔄 Migration Process

### Phase 1: Assessment

1. **Inventory current resources**:
   ```bash
   terraform state list > current-resources.txt
   ```

2. **Document current configuration**:
    - Note custom settings
    - Identify organizational standards
    - List any workarounds or special cases

3. **Plan migration approach**:
    - Choose environment to migrate first (recommend dev)
    - Identify resources that can be moved to modules
    - Plan for any state movements needed

### Phase 2: Preparation

1. **Backup current state**:
   ```bash
   terraform state pull > backup-state.json
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Create new module structure**:
   ```bash
   mkdir -p modules/providers/aws/my-service
   mkdir -p modules/platform/my-service
   ```

3. **Test modules in isolation**:
   ```bash
   cd test-environment
   terraform apply
   ```

### Phase 3: Migration Strategies

#### Strategy A: Green-Field Migration (Recommended)

Create new environment alongside existing one:

```bash
# 1. Create new environment
cp -r environments/dev environments/dev-new

# 2. Update configuration to use modules
# Edit dev-new/main.tf to use modular approach

# 3. Deploy new environment
cd environments/dev-new
terraform init
terraform apply

# 4. Test functionality
kubectl --context new-cluster get nodes

# 5. Switch traffic/applications
# 6. Destroy old environment
```

#### Strategy B: In-Place Migration

Migrate existing environment gradually:

```bash
# 1. Add modules alongside existing resources
# 2. Move state from resources to modules
# 3. Remove old resource definitions
```

**Example state migration**:

```bash
# Move EKS cluster to module
terraform state mv aws_eks_cluster.main module.data_platform.module.cluster.module.eks.aws_eks_cluster.this[0]

# Move node group
terraform state mv aws_eks_node_group.main module.data_platform.module.cluster.module.eks.aws_eks_node_group.main
```

## 📋 Step-by-Step Migration

### Step 1: EKS Cluster Migration

**Before**:

```hcl
resource "aws_eks_cluster" "main" {
  name     = "data-platform-dev"
  role_arn = aws_iam_role.cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }

  # Many more configuration options...
}
```

**After**:

```hcl
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  
  name               = "data-platform"
  environment        = "dev"
  use_aws           = true
  kubernetes_version = "1.28"
  
  # All EKS best practices included automatically
}
```

### Step 2: VPC Migration

**Before**:

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "data-platform-vpc"
  }
}

resource "aws_subnet" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  # ... subnet configuration
}
# ... many more networking resources
```

**After**:

```hcl
# VPC is now handled by the cluster module
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  
  vpc_cidr = "10.0.0.0/16"  # Single configuration line
  # All networking best practices included
}
```

### Step 3: RDS Migration

**Before**:

```hcl
resource "aws_db_instance" "main" {
  identifier = "data-platform-db"
  engine     = "postgres"
  # ... many configuration options
}

resource "aws_db_subnet_group" "main" {
  # ... subnet group configuration
}

resource "aws_security_group" "rds" {
  # ... security group configuration
}
```

**After**:

```hcl
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  
  database_config = {
    engine         = "postgres"
    version        = "16"
    instance_class = "db.t3.micro"
    storage_size   = 20
    # All RDS best practices included
  }
}
```

## 🔧 Configuration Mapping

### Environment Variables

**Before**:

```hcl
variable "cluster_name" {}
variable "vpc_cidr" {}
variable "instance_types" {}
variable "min_size" {}
variable "max_size" {}
# ... many individual variables
```

**After**:

```hcl
variable "node_groups_config" {
  description = "Node groups configuration"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
    # ... structured configuration
  }))
}
```

### Tags and Naming

**Before**:

```hcl
resource "aws_eks_cluster" "main" {
  name = "${var.environment}-${var.project}-cluster"
  
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
    Team        = var.team
  }
}
```

**After**:

```hcl
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  
  # Naming handled automatically: {name}-{environment}
  name        = "data-platform"
  environment = "dev"
  
  # Standard tags applied automatically
  tags = local.common_tags
}
```

## 🚨 Common Migration Challenges

### Challenge 1: State File Complexity

**Problem**: Large state files with many resources
**Solution**: Migrate incrementally, one service at a time

```bash
# Create separate state for new modules
terraform state mv aws_eks_cluster.main terraform-new.tfstate
terraform state mv aws_eks_node_group.main terraform-new.tfstate
```

### Challenge 2: Custom IAM Policies

**Problem**: Existing custom IAM policies need migration
**Solution**: Extend our IAM module or use additional policies

```hcl
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  # ... configuration
}

# Additional custom policies
resource "aws_iam_policy" "custom" {
  name   = "custom-policy"
  policy = data.aws_iam_policy_document.custom.json
}

resource "aws_iam_role_policy_attachment" "custom" {
  role       = module.data_platform.aws_cluster_info.irsa_role_names.custom_service
  policy_arn = aws_iam_policy.custom.arn
}
```

### Challenge 3: Resource Dependencies

**Problem**: Complex resource dependencies
**Solution**: Use module outputs and explicit dependencies

```hcl
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  # ... configuration
}

# Resources that depend on cluster
resource "kubernetes_namespace" "custom" {
  metadata {
    name = "custom-namespace"
  }
  
  depends_on = [module.data_platform]
}
```

## 🧪 Testing Migration

### Pre-Migration Testing

```bash
# 1. Validate current configuration
terraform validate
terraform plan

# 2. Test modules in separate environment
cd test-env
terraform apply
kubectl get nodes

# 3. Compare outputs
terraform output > old-outputs.json
cd ../new-env  
terraform output > new-outputs.json
diff old-outputs.json new-outputs.json
```

### Post-Migration Validation

```bash
# 1. Infrastructure validation
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# 2. Application testing
kubectl apply -f test-app.yaml
kubectl get svc,deploy,pods

# 3. Platform services testing
kubectl port-forward svc/postgres 5432:5432 &
psql -h localhost -p 5432 -c "SELECT 1"

# 4. Monitoring validation
kubectl port-forward svc/grafana 3000:3000 &
curl http://localhost:3000/api/health
```

## 📊 Migration Checklist

### Pre-Migration

- [ ] **Backup current state** and configuration
- [ ] **Test modules** in isolated environment
- [ ] **Plan state movements** if doing in-place migration
- [ ] **Communicate migration** to team
- [ ] **Prepare rollback plan**

### During Migration

- [ ] **Monitor resource creation** during apply
- [ ] **Validate functionality** at each step
- [ ] **Update documentation** as you go
- [ ] **Test applications** after infrastructure changes
- [ ] **Verify monitoring** and logging still work

### Post-Migration

- [ ] **Clean up old resources** (if green-field)
- [ ] **Update CI/CD pipelines** to use new structure
- [ ] **Update team documentation** and runbooks
- [ ] **Train team** on new module usage
- [ ] **Schedule review** of migration success

## 🔄 Rollback Plan

### If Migration Fails

1. **Stop the migration**:
   ```bash
   terraform destroy  # New environment
   ```

2. **Restore original environment**:
   ```bash
   cp terraform.tfstate.backup terraform.tfstate
   terraform plan  # Verify state
   ```

3. **Document issues**:
    - What failed?
    - Why did it fail?
    - How to prevent next time?

4. **Plan retry**:
    - Address root causes
    - Test fixes in isolation
    - Try again with lessons learned

## 📚 Resources

### Migration Tools

- [Terraformer](https://github.com/GoogleCloudPlatform/terraformer) - Import existing infrastructure
- [Terraform State Commands](https://www.terraform.io/docs/cli/commands/state/index.html)
- [terraform-docs](https://terraform-docs.io/) - Generate documentation

### Testing

- [Terratest](https://terratest.gruntwork.io/) - Infrastructure testing framework
- [kitchen-terraform](https://newcontext-oss.github.io/kitchen-terraform/) - Test Kitchen integration

### Documentation

- [Our Architecture Guide](./ARCHITECTURE.md)
- [Module Documentation](./modules/README.md)
- [Update Guide](./UPDATE_GUIDE.md)

---

**Last Updated**: January 2025  
**Migration Support**: infrastructure-team@yourorg.com
