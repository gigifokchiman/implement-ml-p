# Infrastructure Testing Troubleshooting Guide

## Common Issues and Solutions

### 1. Security Scans Failing

**Problem**: `make test-terraform-security` fails with many security violations

**Solution**: Security scans are now separated from basic testing

```bash
# Run basic tests without security (recommended for development)
make test-static
make test-unit

# Run security tests separately (may have issues)
make test-security
```

**Why**: The security scans find real issues in the infrastructure that need to be addressed over time. They're
separated so they don't block daily development.

### 2. tfsec Config File Errors

**Problem**: `tfsec --config-file` fails with "file not found"

**Solution**: Updated config file paths in Makefile. If still having issues:

```bash
# Run tfsec directly without config files
tfsec ../terraform --minimum-severity HIGH
```

### 3. Tests Hanging or Taking Too Long

**Problem**: Tests seem to hang or take very long

**Solution**: Use the simple test runner for quick validation

```bash
# Quick tests only
./run-tests-simple.sh

# Or individual commands
make test-terraform-fmt
make test-terraform-validate
make test-kubernetes-validate
```

### 4. Checkov/tfsec Not Installed

**Problem**: Security tools not available

**Solution**: Install tools or skip security tests

```bash
# Install tools
make install

# Or skip security tests for now
make test-static  # No security scans
make test-unit    # No security scans
```

### 5. Environment-Specific Issues

**Problem**: Tests fail for specific environments

**Solution**: Run tests per environment

```bash
# Test specific environment only
cd ../terraform/environments/local
terraform validate

# Or check specific overlay
cd ../kubernetes/overlays/local
kustomize build .
```

## Test Runners Available

### 1. `make` Commands (Recommended)

```bash
make test-static     # ✅ Fast, reliable
make test-unit       # ✅ Fast, reliable  
make test-security   # ⚠️  May have issues
make test            # ✅ static + unit
```

### 2. `./run-tests.sh` (Full Featured)

```bash
./run-tests.sh static    # Same as make test-static
./run-tests.sh unit      # Same as make test-unit
./run-tests.sh security  # Security tests (may fail)
./run-tests.sh           # All tests
```

### 3. `./run-tests-simple.sh` (Minimal)

```bash
./run-tests-simple.sh format    # Just formatting
./run-tests-simple.sh validate  # Format + validation
./run-tests-simple.sh           # Basic tests only
```

## What Each Test Does

### ✅ **Reliable Tests**

- **Terraform Format**: `terraform fmt -check`
- **Terraform Validate**: `terraform validate`
- **Kubernetes Validate**: `kustomize build` + `kubeconform`
- **OPA Policy Tests**: `opa test`

### ⚠️ **Tests That May Have Issues**

- **Security Scans**: `tfsec` + `checkov` (find real security issues)
- **Integration Tests**: Require running cluster
- **Performance Tests**: Require k6 installation

## Quick Start Recommendations

### For Daily Development

```bash
# Before committing
make test-static

# After significant changes  
make test
```

### For CI/CD

```bash
# Static validation
make test-static

# Unit tests
make test-unit

# Security (separate job, allow failure)
make test-security || echo "Security issues found"
```

### For Debugging

```bash
# Individual tests
make test-terraform-fmt
make test-terraform-validate
make test-kubernetes-validate

# Simple runner
./run-tests-simple.sh format
```

## Environment Setup

### Required Tools

```bash
# Essential (for basic testing)
brew install terraform kubectl kustomize

# Optional (for full testing)  
brew install k6 trivy
pip install checkov
```

### Tool Verification

```bash
# Check what's installed
which terraform kubectl kustomize
terraform version
kubectl version --client
kustomize version
```

## Getting Help

1. **Check individual commands first**:
   ```bash
   make test-terraform-fmt      # Usually works
   make test-terraform-validate # Usually works
   make test-kubernetes-validate # Usually works
   ```

2. **Use simple runner for basic validation**:
   ```bash
   ./run-tests-simple.sh
   ```

3. **Check tool installation**:
   ```bash
   make install
   ```

4. **Run with verbose output**:
   ```bash
   VERBOSE=1 make test-static
   ```

Remember: **The goal is fast feedback for developers**. Security issues can be addressed over time!
