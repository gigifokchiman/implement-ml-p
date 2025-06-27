# Infrastructure Testing Suite

Comprehensive testing framework for ML Platform infrastructure ensuring reliability, security, and performance.

## Overview

This testing suite provides multi-layered validation for infrastructure code, Kubernetes manifests, security compliance,
and system performance.

## Test Categories

### 🏗️ Infrastructure Validation

- **Terraform Tests** - Infrastructure as Code validation
- **Kubernetes Tests** - Manifest and configuration validation

### 🔒 Security & Compliance

- **Security Scanning** - Infrastructure and container security
- **Compliance Checks** - Industry standards validation

### 🚀 Runtime Testing

- **Integration Tests** - End-to-end deployment validation
- **Performance Tests** - Load testing and resource monitoring

## Quick Start

```bash
# Run all basic tests
./tests/run-all.sh

# Run extended tests (includes integration & performance)
./tests/run-all.sh --type extended

# Run tests in parallel
./tests/run-all.sh --parallel --type extended

# Skip specific test categories
./tests/run-all.sh --skip-security --skip-performance
```

## Test Structure

```
tests/
├── run-all.sh              # Master test orchestrator
├── terraform/              # Terraform validation
│   └── validate.sh         # Syntax, security, cost validation
├── kubernetes/              # Kubernetes validation  
│   └── validate.sh         # Manifest, security, policy validation
├── integration/             # End-to-end testing
│   └── deploy-test.sh       # Full deployment testing
├── security/                # Security scanning
│   └── scan.sh             # Multi-tool security analysis
└── performance/             # Performance testing
    └── load-test.sh        # Load testing and monitoring
```

## Test Types

### Basic Tests (Default)

- Terraform validation (fmt, validate, plan)
- Kubernetes manifest validation
- Security scanning (static analysis)

**Duration:** ~5-10 minutes  
**Requirements:** terraform, kubectl, kustomize

### Extended Tests

- All basic tests
- Integration tests (full deployment)
- Performance tests (load testing)
- Autoscaling validation

**Duration:** ~15-30 minutes  
**Requirements:** Basic + kind, ab/wrk, docker

## Individual Test Suites

### Terraform Validation

```bash
./tests/terraform/validate.sh
```

**Tests:**

- ✅ Syntax validation (`terraform fmt`, `terraform validate`)
- ✅ Planning validation (`terraform plan`)
- ✅ Security scanning (Checkov, tfsec)
- ✅ Cost estimation and warnings
- ✅ Tagging compliance
- ✅ Backup configuration validation

### Kubernetes Validation

```bash
./tests/kubernetes/validate.sh
```

**Tests:**

- ✅ Manifest building (`kustomize build`)
- ✅ Kubernetes validation (`kubectl apply --dry-run`)
- ✅ Security policies (security contexts, privileges)
- ✅ Resource limits and requests
- ✅ Image tag policies
- ✅ Storage configuration
- ✅ Health check validation

### Integration Tests

```bash
./tests/integration/deploy-test.sh [basic|extended]
```

**Tests:**

- ✅ Kind cluster creation
- ✅ Ingress controller deployment
- ✅ Application deployment
- ✅ Pod health validation
- ✅ Service connectivity
- ✅ Persistent storage
- ✅ Security context validation
- ✅ Pod restart resilience (extended)

### Security Tests

```bash
./tests/security/scan.sh
```

**Tests:**

- ✅ Infrastructure security (Checkov, tfsec)
- ✅ Kubernetes security (kubesec, kube-score)
- ✅ Container scanning (Trivy)
- ✅ Secret detection (gitleaks, trufflehog)
- ✅ Compliance validation (Pod Security Standards)
- ✅ Network policy validation
- ✅ Backup strategy validation

### Performance Tests

```bash
./tests/performance/load-test.sh [basic|extended]
```

**Tests:**

- ✅ Load testing (Apache Bench, wrk)
- ✅ Resource utilization monitoring
- ✅ Storage performance testing
- ✅ Network latency testing
- ✅ Autoscaling validation (extended)
- ✅ Database performance (extended)

## CI/CD Integration

### GitHub Actions

Tests automatically run on:

- Push to `main`/`develop` branches
- Pull requests to `main`
- Manual workflow dispatch

```yaml
# .github/workflows/infrastructure-tests.yml
name: Infrastructure Tests
on:
  push:
    branches: [main, develop]
    paths: ['infrastructure/**']
  pull_request:
    branches: [main]
```

### Manual Triggers

```bash
# Trigger specific test types via GitHub UI
# - basic: Terraform + Kubernetes validation
# - extended: All tests including integration
# - security: Security-focused testing
# - performance: Performance and load testing
```

## Test Environment Support

### Local Development

- **Platform:** Kind cluster
- **Storage:** local-path storage class
- **Networking:** NodePort services
- **Duration:** Fast validation

### Cloud Environments

- **Platform:** EKS clusters
- **Storage:** EBS volumes
- **Networking:** Load balancers
- **Duration:** Comprehensive testing

## Tool Dependencies

### Required (Core Tests)

```bash
# Install core dependencies
brew install terraform kubectl kustomize  # macOS
apt-get install terraform kubectl          # Linux
```

### Optional (Extended Tests)

```bash
# Security tools
brew install checkov tfsec trivy gitleaks
pip install checkov

# Performance tools  
brew install wrk
apt-get install apache2-utils

# Kubernetes tools
brew install kubesec kube-score
```

### Installation Scripts

```bash
# Install all tools (macOS)
./tests/install-tools-macos.sh

# Install all tools (Linux)  
./tests/install-tools-linux.sh
```

## Test Reports

Tests generate detailed reports in multiple formats:

### Test Summary

- Console output with pass/fail status
- Execution duration for each test suite
- Overall success rate

### Detailed Reports

- **Security Report:** `tests/security/security-report-*.md`
- **Performance Report:** `tests/performance/performance-report-*.md`
- **Integration Report:** Test logs and artifacts

### CI/CD Artifacts

- Test result files uploaded as GitHub Actions artifacts
- Downloadable reports for detailed analysis

## Best Practices

### Development Workflow

1. **Local Testing:** Run basic tests before committing
2. **PR Testing:** Extended tests run automatically
3. **Pre-deployment:** Manual security/performance testing
4. **Post-deployment:** Monitoring and alerting

### Test Maintenance

- **Weekly:** Review and update security scanning rules
- **Monthly:** Update tool versions and dependencies
- **Quarterly:** Review test coverage and add new tests

### Troubleshooting

#### Common Issues

**"Storage class not found"**

```bash
# Update storage class in environment overlay
# For local: local-path
# For AWS: gp2, gp3
```

**"Security scan failures"**

```bash
# Install security tools
brew install checkov tfsec trivy

# Or skip security tests
./tests/run-all.sh --skip-security
```

**"Integration test timeouts"**

```bash
# Check cluster resources
kubectl get nodes
kubectl get pods --all-namespaces

# Increase timeout in test scripts
```

#### Debug Mode

```bash
# Run with verbose output
set -x
./tests/run-all.sh --type extended

# Check individual test logs
./tests/terraform/validate.sh 2>&1 | tee terraform.log
```

## Performance Baselines

### Target Metrics

- **Frontend RPS:** >50 requests/second
- **API Response Time:** <200ms average
- **Pod Startup Time:** <30 seconds
- **Storage I/O:** >100MB/s throughput

### Resource Limits

- **CPU:** 70% target for autoscaling
- **Memory:** 80% target for autoscaling
- **Storage:** 85% warning threshold

## Security Standards

### Compliance Frameworks

- **SOC 2 Type II:** Encryption, access controls, audit logging
- **GDPR:** Data minimization, retention policies
- **PCI DSS:** Network segmentation, encryption (if applicable)

### Security Policies

- Containers run as non-root users
- Read-only root filesystems
- No privileged containers
- Resource limits enforced
- Network policies implemented

## Contributing

### Adding New Tests

1. Create test script in appropriate directory
2. Follow existing naming conventions
3. Add to master test runner (`run-all.sh`)
4. Update documentation
5. Test in CI/CD pipeline

### Test Script Template

```bash
#!/bin/bash
set -euo pipefail

# Test description and purpose
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test functions
test_example() {
    # Test implementation
    return 0
}

# Main execution
main() {
    run_test "Example Test" "test_example"
}

main "$@"
```

## Support

For questions or issues:

- 📖 Check this documentation
- 🐛 Create GitHub issue for bugs
- 💡 Suggest improvements via PR
- 🔧 Check troubleshooting section

---

**Next Steps:** Run `./tests/run-all.sh --help` to get started!
