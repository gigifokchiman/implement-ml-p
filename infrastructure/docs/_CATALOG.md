# Infrastructure Documentation Catalog

This directory contains comprehensive documentation for the ML platform infrastructure.

**Last Updated:** January 2025  
**Total Documentation:** 39 Markdown files across infrastructure

## 📚 Core Documentation

### Essential Reading
- [**NEW-ENGINEER-RUNBOOK.md**](./NEW-ENGINEER-RUNBOOK.md) - 🎓 **Complete hands-on guide for new engineers**
- [**ADD-NEW-APPLICATION.md**](./ADD-NEW-APPLICATION.md) - ⚡ **Quick guide to add new applications in 4 steps**
- [**APPLICATION-TRANSITION.md**](./APPLICATION-TRANSITION.md) - 🚀 **Comprehensive guide to application development**
- [**IMPLEMENTATION-SUMMARY.md**](./IMPLEMENTATION-SUMMARY.md) - Current implementation status and completed features

### Configuration & Setup
- [**BEST-PRACTICES.md**](./BEST-PRACTICES.md) - Terraform coding standards and practices
- [**KIND-CLUSTER-CONFIGURATION.md**](./KIND-CLUSTER-CONFIGURATION.md) - Local Kind cluster setup and configuration
- [**LOCAL-VPC-SIMULATION.md**](./LOCAL-VPC-SIMULATION.md) - Local development VPC simulation

### Operations & Maintenance
- [**MAINTENANCE.md**](./MAINTENANCE.md) - Ongoing maintenance procedures and operational tasks
- [**MONITORING-GUIDE.md**](./MONITORING-GUIDE.md) - Monitoring and observability setup
- [**OPERATIONAL_RUNBOOKS.md**](./OPERATIONAL_RUNBOOKS.md) - Standard operational procedures and troubleshooting
- [**SECURITY.md**](./SECURITY.md) - Security configuration and best practices
- [**SECURITY-SCANNING-GUIDE.md**](./SECURITY-SCANNING-GUIDE.md) - Security scanning tools and procedures
- [**TESTING-GUIDE.md**](./TESTING-GUIDE.md) - Testing strategies and validation procedures

### Cloud Platform Management
- [**EKS-USAGE.md**](./EKS-USAGE.md) - AWS EKS specific configuration and usage

### Network & Infrastructure
- [**INGRESS-SETUP.md**](./INGRESS-SETUP.md) - Ingress controller and routing configuration
- [**PORT-MANAGEMENT.md**](./PORT-MANAGEMENT.md) - Port allocation and management strategies
- [**METRICS-SERVER-CONFIGURATIONS.md**](./METRICS-SERVER-CONFIGURATIONS.md) - Metrics server configuration

### GitOps & Deployment
- [**ARGOCD-COMMANDS-GUIDE.md**](./ARGOCD-COMMANDS-GUIDE.md) - ArgoCD operational commands and workflows
- [**ARGOCD-MIGRATION-GUIDE.md**](./ARGOCD-MIGRATION-GUIDE.md) - ArgoCD migration procedures and best practices

## 🏗️ Architecture Overview

The infrastructure follows a **two-layer architecture**:

1. **Layer 1: Infrastructure (Terraform)** - Manages foundational cloud and compute resources
    - Custom Kind provider (`gigifokchiman/kind`) for local development
    - Modular design with platform abstractions and provider implementations
2. **Layer 2: Applications (Kustomize + ArgoCD)** - GitOps-based application deployments
    - ArgoCD for continuous deployment from Git
    - Environment-specific overlays for local, dev, staging, and prod

## 🚀 Quick Start

1. **New to the project?** Start with [NEW-ENGINEER-RUNBOOK.md](./NEW-ENGINEER-RUNBOOK.md)
2. **Adding a new application?** Use [ADD-NEW-APPLICATION.md](./ADD-NEW-APPLICATION.md) for the 4-step process
3. **Setting up locally?**
    - Kubernetes: Use [`../scripts/deploy-local.sh`](../scripts/deploy-local.sh) or
      follow [KIND-CLUSTER-CONFIGURATION.md](./KIND-CLUSTER-CONFIGURATION.md)
    - Docker Compose: Simply run `docker-compose up -d` from project root
4. **GitOps Setup?** Follow [ARGOCD-MIGRATION-GUIDE.md](./ARGOCD-MIGRATION-GUIDE.md) and use [
   `../scripts/bootstrap-argocd.sh`](../scripts/bootstrap-argocd.sh)
5. **Deploying to AWS?** Review [EKS-USAGE.md](./EKS-USAGE.md) and [BEST-PRACTICES.md](./BEST-PRACTICES.md)
6. **Need monitoring?** Check [MONITORING-GUIDE.md](./MONITORING-GUIDE.md)
7. **Security concerns?** See [SECURITY.md](./SECURITY.md)
   and [SECURITY-SCANNING-GUIDE.md](./SECURITY-SCANNING-GUIDE.md)

## 📦 Archived Documentation

### Legacy Infrastructure
- [**archive/ARCHIVED-KUSTOMIZE-DISCUSSION.md**](./archive/ARCHIVED-KUSTOMIZE-DISCUSSION.md) - Historical Kustomize implementation decisions
- [**archive/AWS-HELM-CHARTS.md**](./archive/AWS-HELM-CHARTS.md) - AWS-specific Helm chart configurations
- [**archive/CLEANUP_SUMMARY.md**](./archive/CLEANUP_SUMMARY.md) - Documentation cleanup summary
- [**archive/DATA-INFRASTRUCTURE.md**](./archive/DATA-INFRASTRUCTURE.md) - Data layer architecture and storage solutions
- [**archive/DOCKER-CONFIG.md**](./archive/DOCKER-CONFIG.md) - Docker configuration and setup
- [**archive/DOCKER-SETUP.md**](./archive/DOCKER-SETUP.md) - Docker setup procedures
- [**archive/ENVIRONMENT-COMPARISON.md**](./archive/ENVIRONMENT-COMPARISON.md) - Environment comparison matrix
- [**archive/INCIDENT-RESPONSE.md**](./archive/INCIDENT-RESPONSE.md) - Incident response procedures and runbooks
- [**archive/INFRASTRUCTURE-ENVIRONMENTS.md**](./archive/INFRASTRUCTURE-ENVIRONMENTS.md) - Environment-specific configurations
- [**archive/INFRASTRUCTURE-IMPROVEMENTS.md**](./archive/INFRASTRUCTURE-IMPROVEMENTS.md) - Planned infrastructure improvements
- [**archive/INFRASTRUCTURE_COMPLETE.md**](./archive/INFRASTRUCTURE_COMPLETE.md) - Infrastructure completion status
- [**archive/KUSTOMIZE-CHALLENGES.md**](./archive/KUSTOMIZE-CHALLENGES.md) - Known challenges and solutions
- [**archive/MIGRATION_GUIDE_MODULAR.md**](./archive/MIGRATION_GUIDE_MODULAR.md) - Modular migration guide
- [**archive/MIGRATION_GUIDE_TESTING.md**](./archive/MIGRATION_GUIDE_TESTING.md) - Testing migration procedures

## 📂 Additional Infrastructure Documentation

### Scripts Documentation

See [`../scripts/`](../scripts/) directory for deployment automation:

- `deploy-local.sh` - Complete local deployment with Kind and ArgoCD
- `bootstrap-argocd.sh` - ArgoCD installation and configuration
- `install-terraform-provider-kind.sh` - Custom Kind provider installation
- `download-kind-provider.sh` - Provider binary download

### Terraform Documentation

- [`../terraform/environments/dev/README.md`](../terraform/environments/dev/README.md) - Development environment setup
- [`../terraform/tests/README.md`](../terraform/tests/README.md) - Terraform testing framework

### Test Documentation

- [`../tests/README.md`](../tests/README.md) - Test suite overview
- [`../tests/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Common issues and solutions
- [`../tests/WORKFLOWS.md`](WORKFLOWS.md) - Test workflow documentation
- [`../tests/terraform/compliance/README.md`](../tests/terraform/compliance/README.md) - Compliance testing

## 📋 Document Status

| Category | Documents | Status |
|----------|-----------|---------|
| **Essential Reading** | 3 docs | ✅ Current |
| **Configuration & Setup** | 3 docs | ✅ Current |
| **Operations & Maintenance** | 6 docs | ✅ Current |
| **Cloud Platform Management** | 1 doc | ✅ Current |
| **Network & Infrastructure** | 3 docs | ✅ Current |
| **GitOps & Deployment** | 2 docs | ✅ Current |
| **Archived Documentation** | 14 docs | 📦 Archived |

**Total Active Documents:** 19 (this directory)  
**Total Archived Documents:** 14 (archive subdirectory)  
**Additional Documentation:** 6 (other infrastructure directories)  
**Total Infrastructure Documentation:** 39 Markdown files

## 🎯 Document Maintenance

This documentation is actively maintained and updated. For questions or improvements:

1. Check existing docs first
2. Review [BEST-PRACTICES.md](./BEST-PRACTICES.md) for coding standards
3. Follow procedures in [MAINTENANCE.md](./MAINTENANCE.md)
4. Use [TESTING-GUIDE.md](./TESTING-GUIDE.md) for validation procedures
5. Create issues for missing documentation

---

**Last Updated:** January 2025  
**Repository:** https://github.com/gigifokchiman/implement-ml-p  
**GitOps:** Managed by ArgoCD
