# Infrastructure Testing - Quick Reference

## 🚀 Most Common Commands

```bash
# Before committing (< 1 min)
make test-static

# After making changes (< 5 min)
make test

# Fix formatting issues
make fix-terraform-fmt

# See all commands
make help
```

## 🧪 What Each Test Does

### `make test-static` (30 seconds)

- ✓ Terraform formatting
- ✓ Terraform syntax validation
- ✓ Kubernetes YAML validation
- ✓ Quick security checks

### `make test` (5 minutes)

- ✓ Everything from test-static
- ✓ Terraform module tests
- ✓ OPA policy tests
- ✓ Security compliance scans

### `make test-integration` (30 minutes)

- ✓ Deploys to test cluster
- ✓ End-to-end validation
- ✓ Performance checks

## 🔧 Fixing Common Issues

| Error                | Fix Command               |
|----------------------|---------------------------|
| Terraform formatting | `make fix-terraform-fmt`  |
| Missing tools        | `make install`            |
| See detailed errors  | Run test with `VERBOSE=1` |

## 📁 Test Structure

```
tests/
├── Makefile           # All commands here
├── terraform/         # Terraform tests
├── kubernetes/        # K8s tests + policies
└── run-tests.sh      # Alternative runner
```

## 💡 Tips

1. **Run `make test-static` before EVERY commit**
2. **Run `make test` after significant changes**
3. **Use `make help` to see all options**
4. **Tests are designed to be FAST**

## 🆘 Need Help?

```bash
# See what a test does
make help

# Run with debug output
VERBOSE=1 make test-static

# Test specific component
make test-terraform
make test-kubernetes
make test-security
```
