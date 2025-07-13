# Provider Version Management

This document explains how to efficiently manage Terraform provider versions across all environments in the data
platform infrastructure.

## Overview

Provider versions are centrally managed to ensure consistency, security, and easier maintenance across all environments.

## File Structure

```
terraform/
├── versions.tf                 # Central version definitions
├── environments/
│   ├── versions-common.tf      # Common providers for all environments
│   ├── versions-local.tf       # Local development specific providers
│   ├── local/main.tf          # References central versions
│   ├── dev/main.tf            # References central versions
│   ├── staging/main.tf        # References central versions
│   └── prod/main.tf           # References central versions
└── scripts/
    └── manage-versions.sh      # Version management automation
```

## Central Version Management

### 1. versions.tf

The `terraform/versions.tf` file is the single source of truth for all provider versions:

```hcl
locals {
  terraform_version = ">= 1.6.0"
  
  provider_versions = {
    aws        = "~> 5.0"
    kubernetes = "~> 2.23"
    helm       = "~> 2.11"
    # ... other providers
  }
}
```

### 2. Environment-Specific Versions

- `versions-common.tf`: Shared across all environments
- `versions-local.tf`: Additional providers for local development (kind, docker)

## Version Constraint Best Practices

### Recommended Patterns

1. **Patch Updates**: `~> 5.1.0` (allows 5.1.x, not 5.2.0)
2. **Minor Updates**: `~> 5.1` (allows 5.x, not 6.0)
3. **Exact Versions**: `= 5.1.0` (only for critical/sensitive providers)
4. **Range Constraints**: `>= 5.0, < 6.0` (for maximum compatibility)

### Environment-Specific Strategies

- **Local**: More permissive (`~> 5.1`) for development flexibility
- **Dev/Staging**: Conservative (`~> 5.1.0`) for testing stability
- **Production**: Exact versions (`= 5.1.2`) for maximum predictability

## Management Commands

### Check Current Versions

```bash
make check-versions                    # All environments
./scripts/manage-versions.sh check local  # Specific environment
```

### Update Versions

```bash
make update-versions-dry-run          # Preview changes
make update-versions                  # Update all environments
make update-versions-local           # Update local only
make update-versions-prod            # Update production (with confirmation)
```

### Validate After Updates

```bash
make validate-versions               # Validate all environments
```

## Automated Updates

### Dependabot Configuration

The `.github/dependabot.yml` automatically creates PRs for:

- Weekly updates for dev/staging
- Monthly updates for production
- Patch and minor updates only (major versions require manual review)

### CI/CD Integration

```yaml
name: Provider Version Check
on:
  schedule:
    - cron: '0 9 * * 1'  # Weekly on Monday
  
jobs:
  check-versions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make check-versions
      - run: make validate-versions
```

## Update Workflow

### 1. Development Updates

```bash
# Check current versions
make check-versions

# Preview updates
make update-versions-dry-run

# Apply updates to non-production
make update-versions-local
make update-versions-dev

# Test the changes
make init-dev
make plan-dev
```

### 2. Production Updates

```bash
# Test in staging first
make update-versions-staging
make apply-staging

# After successful staging validation
make update-versions-prod
make apply-prod
```

### 3. Emergency Updates (Security)

```bash
# For critical security updates
./scripts/manage-versions.sh update --provider aws --force
make validate-versions
```

## Version Pinning Strategy

### When to Pin Exact Versions

- **Production**: Pin to exact versions after testing
- **Security**: Pin when using providers with known vulnerabilities
- **Stability**: Pin when using bleeding-edge features

### When to Use Ranges

- **Development**: Use ranges for flexibility
- **Testing**: Use ranges to catch compatibility issues early
- **Non-critical**: Use ranges for non-infrastructure-critical providers

## Troubleshooting

### Common Issues

1. **Version Conflicts**
   ```bash
   # Clear lock files and reinitialize
   rm -f .terraform.lock.hcl
   terraform init -upgrade
   ```

2. **Compatibility Issues**
   ```bash
   # Check provider documentation for breaking changes
   terraform providers
   ```

3. **Lock File Inconsistencies**
   ```bash
   # Regenerate lock file for all platforms
   terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
   ```

## Version History Tracking

### Changelog Format

```markdown
## Provider Updates - 2024-01-15

### Updated
- AWS Provider: 5.0.1 → 5.1.0
  - Added support for new EC2 instance types
  - Fixed EKS node group issue

### Security
- Kubernetes Provider: 2.23.0 → 2.23.1
  - CVE-2024-XXXX fix
```

## Best Practices

### 1. Testing Strategy

- Test version updates in local environment first
- Validate in dev/staging before production
- Run full test suite after version updates

### 2. Communication

- Announce major version updates to the team
- Document breaking changes in CHANGELOG.md
- Use PR descriptions to explain version update impacts

### 3. Rollback Strategy

- Keep backup of working lock files
- Use exact version pins for easy rollback
- Test rollback procedures in non-production

### 4. Monitoring

- Monitor for deprecation warnings
- Track provider update frequency
- Monitor for security advisories

## Emergency Procedures

### Critical Security Update

1. Identify affected environments
2. Update versions.tf with fixed version
3. Apply to all environments immediately
4. Validate functionality
5. Document the emergency change

### Version Rollback

1. Restore previous versions.tf
2. Restore .terraform.lock.hcl files
3. Run terraform init
4. Validate rollback success
5. Investigate and fix root cause

## Related Documentation

- [Terraform Version Management](./TERRAFORM-VERSION-MANAGEMENT.md)
- [Security Update Procedures](./SECURITY-UPDATE-PROCEDURES.md)
- [Environment Management](./ENVIRONMENT-MANAGEMENT.md)
