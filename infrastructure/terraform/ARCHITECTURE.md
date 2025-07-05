# Infrastructure Architecture Documentation

## Overview

This infrastructure uses a **modular wrapper approach** that leverages best-in-class open source Terraform modules while
providing organizational consistency and environment abstraction.

## 🎯 Design Principles

1. **Leverage Open Source Excellence**: Use community-maintained modules without modification
2. **Maintain Organizational Consistency**: Provide unified interfaces across environments
3. **Enable Environment Portability**: Same code works for local and cloud deployments
4. **Future-Proof Updates**: Easy to adopt upstream changes and new features

## 📁 Architecture Layers

```
environments/          # Environment-specific configurations
├── local/            # Kind cluster for development
├── dev/              # AWS EKS for development
├── staging/          # AWS EKS for staging
└── prod/             # AWS EKS for production

modules/
├── compositions/     # High-level service orchestration
│   └── data-platform/    # Complete data platform stack
├── platform/        # Provider-agnostic interfaces
│   ├── cluster/          # Unified cluster interface
│   ├── database/         # Database abstraction
│   ├── cache/            # Cache abstraction
│   └── storage/          # Storage abstraction
└── providers/        # Provider-specific implementations
    ├── aws/              # AWS-specific modules (wrapping open source)
    │   ├── cluster/          # EKS wrapper
    │   ├── database/         # RDS wrapper
    │   └── cache/            # ElastiCache wrapper
    └── kubernetes/       # Kubernetes-specific modules
        ├── cluster/          # Kind cluster implementation
        ├── database/         # In-cluster database
        └── cache/            # In-cluster cache
```

## 🔄 Open Source Module Integration

### Current Modules Used

| Open Source Module          | Version   | Purpose                | Wrapper Location           |
|-----------------------------|-----------|------------------------|----------------------------|
| `terraform-aws-modules/eks` | `~> 20.0` | EKS cluster management | `/providers/aws/cluster/`  |
| `terraform-aws-modules/vpc` | `~> 5.0`  | VPC and networking     | `/providers/aws/cluster/`  |
| `terraform-aws-modules/rds` | `~> 6.0`  | RDS database           | `/providers/aws/database/` |

### Integration Pattern

```hcl
# Our wrapper module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"  # ← Open source module
  version = "~> 20.0"
  
  # Pass through our standardized configuration
  cluster_name = local.name_prefix
  vpc_id       = module.vpc.vpc_id
  # ... our platform-specific defaults
}
```

### Benefits

✅ **No Modifications**: Open source modules used exactly as-is  
✅ **Easy Updates**: Bump version numbers to get latest features  
✅ **Full Feature Access**: All upstream capabilities available  
✅ **Community Support**: Benefit from community testing and improvements  
✅ **Best Practices**: Built-in security and performance optimizations

## 🌍 Environment Abstraction

### Unified Interface

Both local and cloud environments use the same data-platform composition:

```hcl
module "data_platform" {
  source = "../../modules/compositions/data-platform"
  
  name        = "data-platform"
  environment = "dev"
  use_aws     = true  # ← Controls provider selection
  
  # Same configuration works for both environments
  node_groups         = var.node_groups
  team_configurations = var.team_configurations
}
```

### Provider Selection

| Environment | `use_aws` | Result                             |
|-------------|-----------|------------------------------------|
| `local/`    | `false`   | Kind cluster + in-cluster services |
| `dev/`      | `true`    | EKS + AWS managed services         |
| `staging/`  | `true`    | EKS + AWS managed services         |
| `prod/`     | `true`    | EKS + AWS managed services         |

## 🔧 Module Update Process

### 1. Monitor Upstream Changes

```bash
# Check for new releases
terraform init -upgrade
terraform plan  # Review changes
```

### 2. Update Version Constraints

```hcl
# Before
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
}

# After
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"  # New major version
}
```

### 3. Test in Development

```bash
cd environments/dev
terraform plan
terraform apply
```

### 4. Update Documentation

Document any new features or breaking changes in this file.

## 🏗️ Adding New Open Source Modules

### Step 1: Evaluate Module

**Checklist:**

- [ ] Actively maintained (recent commits)
- [ ] Good documentation
- [ ] High adoption (stars/downloads)
- [ ] Follows Terraform best practices
- [ ] Compatible with our standards

### Step 2: Create Wrapper Module

```bash
mkdir -p modules/providers/aws/new-service
```

**Template:**

```hcl
# modules/providers/aws/new-service/main.tf
module "upstream_module" {
  source  = "terraform-aws-modules/new-service/aws"
  version = "~> 1.0"
  
  # Map our platform interface to upstream interface
  name = var.name
  # ... other mappings
  
  tags = var.tags
}
```

### Step 3: Create Platform Interface

```bash
mkdir -p modules/platform/new-service
```

**Template:**

```hcl
# modules/platform/new-service/main.tf
module "aws_implementation" {
  count  = var.use_aws ? 1 : 0
  source = "../../providers/aws/new-service"
  # ... configuration
}

module "kubernetes_implementation" {
  count  = var.use_aws ? 0 : 1  
  source = "../../providers/kubernetes/new-service"
  # ... configuration
}
```

### Step 4: Integration Testing

1. Test in local environment
2. Test in dev environment
3. Update composition if needed
4. Document usage

## 📋 Maintenance Guidelines

### Version Management

**Semantic Versioning:**

- `~> 20.0` - Allow patch updates (20.0.x)
- `~> 20.1` - Allow minor updates (20.1.x)
- `>= 20.0, < 21.0` - Explicit range

**Update Strategy:**

- **Patch updates**: Apply automatically in dev
- **Minor updates**: Test in dev, then promote
- **Major updates**: Careful review, test thoroughly

### Breaking Changes

When upstream modules have breaking changes:

1. **Read the CHANGELOG** carefully
2. **Test in isolated environment** first
3. **Update wrapper modules** to handle changes
4. **Update documentation** with migration notes
5. **Communicate changes** to team

### Security Updates

**High Priority:**

- Security patches: Apply within 1 week
- CVE fixes: Apply within 24-48 hours
- Compliance updates: Apply per policy requirements

## 🚀 Deployment Patterns

### Local Development

```bash
cd environments/local
terraform apply  # Kind cluster + local services
```

### Cloud Development

```bash
cd environments/dev  
terraform apply  # EKS cluster + AWS services
```

### Production Deployment

```bash
cd environments/prod
terraform plan   # Review changes
terraform apply  # Apply with approval
```

## 🔍 Troubleshooting

### Common Issues

**Module Version Conflicts:**

```bash
terraform init -upgrade
rm -rf .terraform.lock.hcl
terraform init
```

**Provider Configuration:**

```bash
# Check provider versions
terraform version
terraform providers
```

**State Management:**

```bash
# Refresh state
terraform refresh
terraform plan
```

### Debug Process

1. **Check Terraform logs**:
   ```bash
   export TF_LOG=DEBUG
   terraform apply
   ```

2. **Validate configuration**:
   ```bash
   terraform validate
   terraform fmt -check
   ```

3. **Review upstream docs**:
    - Check module documentation
    - Review examples in upstream repo
    - Check for known issues

## 📚 Learning Resources

### Terraform Module Development

- [Terraform Module Best Practices](https://www.terraform.io/docs/modules/index.html)
- [HashiCorp Module Guidelines](https://www.terraform.io/registry/modules/publish)

### AWS Terraform Modules

- [terraform-aws-modules Organization](https://github.com/terraform-aws-modules)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Our Specific Modules

- [EKS Module Documentation](https://github.com/terraform-aws-modules/terraform-aws-eks)
- [VPC Module Documentation](https://github.com/terraform-aws-modules/terraform-aws-vpc)
- [RDS Module Documentation](https://github.com/terraform-aws-modules/terraform-aws-rds)

## 🤝 Contributing

### Adding New Features

1. Check if upstream module supports the feature
2. Update wrapper module to expose it
3. Add platform-level interface if needed
4. Update documentation
5. Test in dev environment

### Reporting Issues

1. Check if issue is in upstream module
2. If upstream: Report to upstream repo
3. If wrapper: Create issue in our repo
4. Include full error logs and configuration

---

**Last Updated**: January 2025  
**Maintainers**: Infrastructure Team  
**Contact**: infrastructure@yourorg.com
