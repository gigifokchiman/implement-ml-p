# Infrastructure Documentation Catalog

This directory contains comprehensive documentation for the ML platform infrastructure.

## 📚 Core Documentation

### Essential Reading
- [**NEW-ENGINEER-RUNBOOK.md**](./NEW-ENGINEER-RUNBOOK.md) - 🎓 **Complete hands-on guide for new engineers**
- [**IMPLEMENTATION-SUMMARY.md**](./IMPLEMENTATION-SUMMARY.md) - Current implementation status and completed features
- [**APPLICATION-TRANSITION.md**](./APPLICATION-TRANSITION.md) - 🚀 **Guide to transition from infrastructure to application development**

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
2. **Layer 2: Applications (Kustomize)** - Manages application deployments and configurations

## 🚀 Quick Start

1. **New to the project?** Start with [NEW-ENGINEER-RUNBOOK.md](./NEW-ENGINEER-RUNBOOK.md)
2. **Setting up locally?** Follow [KIND-CLUSTER-CONFIGURATION.md](./KIND-CLUSTER-CONFIGURATION.md) and [DOCKER-SETUP.md](archive/DOCKER-SETUP.md)
3. **Deploying to AWS?** Review [EKS-USAGE.md](./EKS-USAGE.md) and [BEST-PRACTICES.md](./BEST-PRACTICES.md)
4. **Need monitoring?** Check [MONITORING-GUIDE.md](./MONITORING-GUIDE.md)
5. **Security concerns?** See [SECURITY.md](./SECURITY.md) and [SECURITY-SCANNING-GUIDE.md](./SECURITY-SCANNING-GUIDE.md)

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

**Total Active Documents:** 18  
**Total Archived Documents:** 14  
**Total Documentation:** 32 files

## 🎯 Document Maintenance

This documentation is actively maintained and updated. For questions or improvements:

1. Check existing docs first
2. Review [BEST-PRACTICES.md](./BEST-PRACTICES.md) for coding standards
3. Follow procedures in [MAINTENANCE.md](./MAINTENANCE.md)
4. Use [TESTING-GUIDE.md](./TESTING-GUIDE.md) for validation procedures
5. Create issues for missing documentation

---

**Last Updated:** July 2025  
**Maintained By:** Infrastructure Team
