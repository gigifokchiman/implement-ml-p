# Migration Guide: From Shell Scripts to Modern Testing

## Why Migrate?

### Problems with Current Shell Scripts

1. **Brittle Function Calls**
   ```bash
   # Current approach - breaks easily
   if bash -c "$test_command"; then
   ```
   Functions aren't available in subshells!

2. **No Proper Assertions**
   ```bash
   # Current approach
   if [[ $failed_tests -eq 0 ]]; then
       echo "SUCCESS"
   ```
   No rich assertions, hard to debug failures

3. **Poor Error Handling**
   - No automatic retries for flaky operations
   - Cleanup often fails
   - Hard to trace errors

4. **Maintenance Nightmare**
   - Copy-paste code everywhere
   - No IDE support
   - No type checking

## New Testing Architecture

### 1. Static Analysis (< 1 minute)
**Tools**: Native validators, linters
```bash
make test-static
```
- Terraform fmt & validate
- Kustomize build validation
- Security scanning (tfsec, checkov)

### 2. Unit Tests (< 5 minutes)
**Tools**: Terraform test, OPA test
```bash
make test-unit
```
- Test Terraform modules in isolation
- Test OPA policies with test cases
- No infrastructure required

### 3. Integration Tests (~ 30 minutes)
**Tools**: Terratest, actual deployments
```bash
make test-integration
```
- Deploy to ephemeral environments
- Test actual resources
- End-to-end validation

## Migration Steps

### Phase 1: Add New Tests (Don't Remove Old Ones Yet)

1. **Install new tools**
   ```bash
   cd infrastructure/tests
   make install
   ```

2. **Run new static tests**
   ```bash
   make test-static
   ```

3. **Fix any issues found**

### Phase 2: Migrate Critical Tests

1. **Terraform validation → Native tests**
   ```hcl
   # tests/unit/network.tftest.hcl
   run "valid_vpc_cidr" {
     command = plan
     assert {
       condition = var.vpc_cidr != ""
       error_message = "VPC CIDR required"
     }
   }
   ```

2. **Kubernetes validation → kubeconform + OPA**
   ```bash
   # Fast manifest validation
   kustomize build overlays/prod | kubeconform -summary
   
   # Policy validation
   opa eval -d policies/ -i manifest.yaml "data.kubernetes.security.deny"
   ```

### Phase 3: Deprecate Shell Scripts

1. Keep shell scripts as thin wrappers initially
2. Gradually move logic to proper tools
3. Eventually remove shell scripts

## Quick Wins

### 1. Terraform Formatting
**Before**: Complex shell script with eval
**After**: `make test-terraform-fmt`

### 2. Security Scanning
**Before**: Manual checks, easy to miss
**After**: Automated with `make test-security`

### 3. Kubernetes Validation
**Before**: Slow kubectl dry-run
**After**: Fast kubeconform validation

## Tool Comparison

| Task | Old (Shell) | New (Native Tools) |
|------|-------------|-------------------|
| Terraform validation | bash -c, eval | terraform test |
| K8s validation | kubectl dry-run | kubeconform |
| Security | grep patterns | checkov, tfsec, OPA |
| Integration | brittle scripts | Terratest |
| Speed | Slow (~10 min) | Fast (~1 min static) |
| Debugging | print statements | Proper stack traces |
| CI Integration | Flaky | Reliable |

## Example: Complete Test Run

```bash
# Old approach (slow, brittle)
./run-all.sh

# New approach (fast, reliable)
make test          # Static + unit (fast)
make test-integration  # Only when needed
```

## Benefits

1. **Speed**: Static tests run in seconds
2. **Reliability**: Proper error handling
3. **Maintainability**: Tests next to code
4. **Developer Experience**: IDE support, fast feedback
5. **CI/CD**: Reliable, parallelizable

## Getting Started

```bash
# Try the new framework
cd infrastructure/tests
make install
make test-static  # See immediate results!
```

## Support

- Questions? Check the README.md
- Issues? File a GitHub issue
- Need help migrating? Ask the platform team