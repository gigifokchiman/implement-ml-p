# Developer Workflows

This document shows how to integrate infrastructure testing into your daily workflow.

## 🏃‍♂️ Daily Development Workflow

### 1. Before Starting Work

```bash
cd infrastructure/tests

# Ensure you have latest tools
make install

# Quick sanity check
make test-static
```

### 2. While Developing

```bash
# After each significant change
make test-static

# If you see format errors
make fix-terraform-fmt
```

### 3. Before Committing

```bash
# Run comprehensive tests
make test

# Only commit if all tests pass ✅
git add .
git commit -m "your changes"
```

### 4. Before Creating PR

```bash
# Run security scans
make test-security

# Check everything still works
make test
```

## 🔄 Specific Workflows

### Adding New Terraform Module

1. **Create the module**
   ```bash
   # Your new module in terraform/modules/my-module/
   ```

2. **Add unit tests**
   ```hcl
   # tests/terraform/unit/my-module.tftest.hcl
   run "basic_validation" {
     command = plan
     module {
       source = "../../modules/my-module"
     }
     variables {
       name = "test"
     }
     assert {
       condition = output.id != ""
       error_message = "Must output an ID"
     }
   }
   ```

3. **Test your module**
   ```bash
   make test-terraform-unit
   ```

### Adding New Kubernetes Resources

1. **Create/modify manifests**
   ```bash
   # In kubernetes/overlays/dev/
   ```

2. **Validate manifests**
   ```bash
   make test-kubernetes-validate
   ```

3. **Check security policies**
   ```bash
   make test-kubernetes-policies
   ```

4. **If policies fail, fix manifests**
   ```yaml
   # Add required fields like:
   securityContext:
     runAsNonRoot: true
     runAsUser: 1000
   resources:
     limits:
       memory: "128Mi"
       cpu: "100m"
   ```

### Updating Security Policies

1. **Create new OPA policy**
   ```rego
   # kubernetes/policies/my-policy.rego
   package kubernetes.mypolicy
   
   deny[msg] {
     input.kind == "Service"
     input.spec.type == "LoadBalancer"
     msg := "LoadBalancer services not allowed"
   }
   ```

2. **Add policy tests**
   ```rego
   # kubernetes/policies/my-policy_test.rego
   test_deny_loadbalancer {
     deny[_] with input as {
       "kind": "Service",
       "spec": {"type": "LoadBalancer"}
     }
   }
   ```

3. **Test policies**
   ```bash
   make test-policies
   ```

### Debugging Failed Tests

#### Terraform Validation Fails

```bash
# See detailed error
cd ../terraform/environments/dev
terraform init
terraform validate

# Common issues:
# - Missing variables in terraform.tfvars
# - Incorrect module source paths
# - Provider version conflicts
```

#### Security Scan Fails

```bash
# See specific violations
make test-security

# Example fix for S3 bucket:
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

#### Kubernetes Policy Violation

```bash
# See which policies failed
make test-kubernetes-policies

# Example fix - add security context:
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: app
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
```

## 🤖 CI/CD Integration

### GitHub Actions Example

```yaml
name: Infrastructure Tests

on: [ push, pull_request ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        working-directory: infrastructure/tests
        run: make install

      - name: Static tests
        working-directory: infrastructure/tests
        run: make test-static

      - name: Unit tests
        working-directory: infrastructure/tests
        run: make test-unit

      - name: Security tests
        working-directory: infrastructure/tests
        run: make test-security
```

### Local Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
cd infrastructure/tests
make test-static || exit 1
```

## 📊 Performance Guidelines

### Test Speed Targets

- **Static tests**: < 30 seconds
- **Unit tests**: < 5 minutes
- **Security tests**: < 2 minutes
- **Integration tests**: < 30 minutes

### When to Run What

| Frequency     | Tests                  | Time |
|---------------|------------------------|------|
| Every save    | Static only            | 30s  |
| Before commit | Static + Unit          | 5m   |
| Before PR     | All except integration | 7m   |
| In CI         | All tests              | 30m  |

## 🎯 Best Practices

### DO ✅

- Run `make test-static` frequently
- Fix formatting issues immediately
- Add tests for new infrastructure
- Keep tests fast and focused
- Use provided fix commands

### DON'T ❌

- Commit with failing tests
- Skip security scans
- Write tests that need real AWS credentials
- Make tests dependent on external services
- Ignore test failures

## 🔍 Troubleshooting

### "Command not found" errors

```bash
# Install missing tools
make install

# Check what's installed
which terraform
which kubectl
which kustomize
```

### "Tests are slow"

```bash
# Run only what you need
make test-static        # Fastest
make test-terraform     # Terraform only
make test-kubernetes    # K8s only
```

### "Can't figure out what failed"

```bash
# Run with verbose output
VERBOSE=1 make test

# Run individual components
make test-terraform-fmt
make test-terraform-validate
make test-kubernetes-validate
```

Remember: **Tests are your safety net** - they catch issues before they reach production!
