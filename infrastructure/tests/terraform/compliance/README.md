# Environment-Specific Security Compliance

This directory contains security scanning configurations that apply different levels of strictness based on the
environment.

## Security Philosophy

We use a **graduated security approach**:

```
Production/Staging    →  STRICT     (Zero tolerance)
Development          →  MODERATE   (Balanced)  
Local               →  RELAXED    (Developer-friendly)
```

## Configuration Files

### Checkov (Policy as Code)

| File                       | Environment   | Severity               | Skipped Checks            |
|----------------------------|---------------|------------------------|---------------------------|
| `checkov-production.yaml`  | prod, staging | HIGH, CRITICAL, MEDIUM | **None**                  |
| `checkov-development.yaml` | dev           | HIGH, CRITICAL         | Minimal (resource limits) |
| `checkov-local.yaml`       | local         | CRITICAL only          | Many (Kind limitations)   |

### tfsec (Terraform Security)

| File                     | Environment   | Severity      | Skipped Checks         |
|--------------------------|---------------|---------------|------------------------|
| `tfsec-production.yaml`  | prod, staging | MEDIUM+       | **None**               |
| `tfsec-development.yaml` | dev           | HIGH+         | Few (testing needs)    |
| `tfsec-local.yaml`       | local         | CRITICAL only | Many (local dev needs) |

## Why Environment-Specific?

### 🏭 **Production: Zero Tolerance**

- **ALL** security checks must pass
- No exemptions for convenience
- Fail builds on ANY security issue
- Full encryption, logging, monitoring required

### 🧪 **Development: Balanced**

- Most security checks enforced
- Limited exemptions for testing needs
- Resource optimization allowed
- Build failures on high/critical only

### 💻 **Local: Developer-Friendly**

- Only critical security issues block development
- Kind cluster limitations accommodated
- Local MinIO doesn't need AWS S3 features
- Focus on catching real security issues, not dev environment constraints

## Examples

### ✅ **Allowed in Local, Blocked in Production**

```hcl
# Local: OK for testing
resource "aws_s3_bucket" "example" {
  bucket = "test-bucket"
  # No encryption - OK for local MinIO simulation
}

# Production: REQUIRED
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### ✅ **Image Tags**

```yaml
# Local: OK
image: myapp:latest

# Development: OK for testing
image: myapp:feature-branch

# Production: REQUIRED
image: myapp:v1.2.3-sha256-abc123
```

## Running Security Scans

### All Environments

```bash
make test-terraform-security
```

### Specific Environment

```bash
# Local only (most permissive)
checkov --config-file terraform/compliance/checkov-local.yaml

# Development only (moderate)
checkov --config-file terraform/compliance/checkov-development.yaml

# Production only (strictest)
checkov --config-file terraform/compliance/checkov-production.yaml
```

## Adding New Security Rules

### 1. Add to Production First

Always start with the strictest environment:

```yaml
# tfsec-production.yaml
exclude: [ ]  # No exceptions
```

### 2. Consider Development Needs

```yaml
# tfsec-development.yaml
exclude:
  - specific-rule-id  # Only if justified for testing
```

### 3. Local Development Last

```yaml
# tfsec-local.yaml
exclude:
  - rule-that-breaks-kind-cluster
  - rule-incompatible-with-local-dev
  - rules-requiring-aws-features-not-in-kind
```

## Security Rule Justification

Every skipped check must be justified:

| Check            | Local | Dev | Prod | Justification                       |
|------------------|-------|-----|------|-------------------------------------|
| S3 Encryption    | ❌     | ✅   | ✅    | Local uses MinIO simulation         |
| Image Tags       | ❌     | ⚠️  | ✅    | Local/dev need flexibility          |
| Resource Limits  | ❌     | ⚠️  | ✅    | Local has different constraints     |
| Network Policies | ❌     | ✅   | ✅    | Kind cluster networking limitations |
| Kind Provider    | ✅     | ❌   | ❌    | Only local uses gigifokchiman/kind  |

## Best Practices

1. **Default to Strict**: New rules apply to all environments
2. **Justify Exemptions**: Document why local/dev needs exemption
3. **Regular Review**: Audit exemptions quarterly
4. **Minimize Drift**: Keep environments as similar as possible
5. **Test Production Rules**: Validate in staging first

## CI/CD Integration

```yaml
# GitHub Actions example
- name: Security Scan Production
  run: checkov --config-file terraform/compliance/checkov-production.yaml
  # This will fail the build on ANY security issue

- name: Security Scan Development
  run: checkov --config-file terraform/compliance/checkov-development.yaml
  # This has moderate checks

- name: Security Scan Local
  run: checkov --config-file terraform/compliance/checkov-local.yaml
  continue-on-error: true  # Don't block developer workflows
```

Remember: **Security requirements increase as code moves toward production!**
