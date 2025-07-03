# Infrastructure Testing Guide

This guide explains our infrastructure testing strategy and how to run tests effectively.

## Testing Philosophy

We follow a **pyramid testing approach** for infrastructure:

```
         Integration Tests
        /                 \    (slowest, most realistic)
       /   Compliance      \
      /    & Security       \
     /                       \
    /      Unit Tests         \
   /                           \
  /      Static Analysis        \
 /_____________________________ \  (fastest, immediate feedback)
```

## What We Test

### 1. Static Analysis (< 30 seconds)

**Purpose**: Catch syntax errors and formatting issues before anything runs

- **Terraform Format** - Ensures consistent code style
- **Terraform Validate** - Checks HCL syntax is correct
- **Kubernetes Validate** - Validates YAML manifests can be built
- **Basic Security Checks** - Catches obvious security issues

### 2. Compliance & Security (< 2 minutes)

**Purpose**: Enforce security policies and best practices

- **Terraform Security** - Scans for misconfigurations (tfsec, checkov)
- **Kubernetes Policies** - OPA policies for security standards
- **Resource Policies** - Ensures proper resource limits
- **Network Policies** - Validates network segmentation

### 3. Unit Tests (< 5 minutes)

**Purpose**: Test individual modules work correctly

- **Terraform Module Tests** - Tests modules in isolation
- **Policy Tests** - Validates OPA policies work as expected
- **Mock Testing** - Tests without real infrastructure

### 4. Integration Tests (15-30 minutes)

**Purpose**: Validate everything works together

- **Deployment Tests** - Actually deploys to test environment
- **End-to-End Tests** - Tests complete workflows
- **Performance Tests** - Basic load testing

## How to Run Tests

### Prerequisites

```bash
# Install required tools (one-time setup)
cd infrastructure/tests
make install

# For Kind cluster setup with gigifokchiman provider
cd ../scripts
./download-kind-provider.sh
```

### For Developers (Daily Use)

#### Before Committing Code
```bash
# Run fast checks (< 1 minute)
make test-static

# If you see formatting errors
make fix-terraform-fmt
```

#### After Making Changes
```bash
# Run static + unit tests (< 5 minutes)
make test

# Run specific test types
make test-terraform      # Just Terraform tests
make test-kubernetes     # Just Kubernetes tests
make test-security       # Just security scans
```

### For CI/CD Pipeline

```yaml
# In your pipeline
- name: Static Tests
  run: make test-static

- name: Security Tests
  run: make test-security

- name: Unit Tests
  run: make test-unit

# Only on main branch
- name: Integration Tests
  run: make test-integration
```

## Understanding Test Results

### ✅ Success Output

```
🔍 Checking Terraform formatting...
✅ Terraform formatting OK

🔍 Validating Terraform configurations...
  Validating local environment...
  Validating dev environment...
✅ Terraform validation passed
```

### ❌ Failure Output
```
🔍 Checking Terraform formatting...
❌ Run 'make fix-terraform-fmt' to fix

🔍 Running security scans...
❌ HIGH: S3 bucket has public access enabled
  File: terraform/modules/storage/main.tf:45
```

## Common Test Scenarios

### Scenario 1: "My Terraform won't validate"
```bash
# See detailed errors
cd ../terraform/environments/dev
terraform init
terraform validate

# For local environment with Kind provider issues:
cd ../../../scripts
./download-kind-provider.sh

# Common fixes:
# - Missing required variables
# - Module source paths incorrect
# - Provider version conflicts
# - Kind provider not installed (gigifokchiman/kind)
```

### Scenario 2: "Security scan is failing"
```bash
# Run security scan with details
make test-security

# See specific issues
tfsec ../terraform --format json | jq '.results[]'

# Common issues:
# - S3 buckets without encryption
# - RDS without backup retention
# - Security groups with 0.0.0.0/0
```

### Scenario 3: "Kubernetes manifests failing"
```bash
# Test specific overlay
cd kubernetes/validation
./validate.sh local

# Or run from tests directory
make test-kubernetes-validate

# Common issues:
# - Invalid YAML syntax
# - Missing required fields
# - Resource limits not set
```

## Test Types in Detail

### Terraform Tests

| Test     | Purpose              | Tool                 | Fix Command              |
|----------|----------------------|----------------------|--------------------------|
| Format   | Code style           | `terraform fmt`      | `make fix-terraform-fmt` |
| Validate | Syntax check         | `terraform validate` | Fix syntax errors        |
| Security | Find vulnerabilities | `tfsec`, `checkov`   | Fix security issues      |
| Unit     | Test modules         | `terraform test`     | Fix module logic         |

### Kubernetes Tests

| Test     | Purpose              | Tool              | Fix Command           |
|----------|----------------------|-------------------|-----------------------|
| Build    | Can manifests build? | `kustomize build` | Fix YAML syntax       |
| Validate | Are manifests valid? | `kubeconform`     | Fix K8s API issues    |
| Policies | Security compliance  | `opa eval`        | Fix policy violations |

## Writing New Tests

### Adding Terraform Tests

```hcl
# terraform/unit/my_module.tftest.hcl
run "test_name" {
  command = plan
  
  module {
    source = "../../modules/my_module"
  }
  
  variables {
    name = "test"
  }
  
  assert {
    condition     = output.id != ""
    error_message = "ID should not be empty"
  }
}
```

### Adding OPA Policies

```rego
# kubernetes/policies/my_policy.rego
package kubernetes.mypolicy

deny[msg] {
  input.kind == "Deployment"
  not input.spec.replicas
  msg := "Deployment must specify replicas"
}
```

### Adding Policy Tests

```rego
# kubernetes/policies/my_policy_test.rego
test_deny_missing_replicas {
  deny[_] with input as {
    "kind": "Deployment",
    "spec": {}
  }
}
```

## Debugging Failed Tests

### Enable Verbose Output
```bash
# See what's happening
VERBOSE=1 make test

# Run specific test with debug
terraform test -test-directory=terraform/unit -verbose
```

### Common Issues and Solutions

1. **"Docker not available"**
    - Start Docker Desktop
    - Or skip local tests: `make test-static test-unit`

2. **"terraform: command not found"**
    - Install Terraform: `brew install terraform`
    - Or use tfenv: `tfenv install 1.6.0`

3. **"Policy violations found"**
    - Run: `make test-kubernetes-policies`
    - Check which policies failed
    - Update manifests to comply

## Best Practices

1. **Run tests frequently**
    - Before every commit: `make test-static`
    - After changes: `make test`

2. **Fix issues immediately**
    - Don't commit with failing tests
    - Use fix commands when available

3. **Add tests for new code**
    - New module? Add unit tests
    - New security requirement? Add OPA policy

4. **Keep tests fast**
    - Static tests should be instant
    - Unit tests should be quick
    - Only integration tests can be slow

## Getting Help

```bash
# See all available commands
make help

# Run specific test type
make test-<TAB>  # Auto-completion

# See test source
cat Makefile
```

## Summary

- **Static tests** - Run constantly (every save)
- **Unit tests** - Run before commits
- **Security tests** - Run before PRs
- **Integration tests** - Run in CI/CD

Remember: The goal is to catch issues early when they're cheap to fix!
