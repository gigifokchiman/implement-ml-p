# ML Platform Infrastructure

> **A modern, production-ready ML platform built on Kubernetes and GitOps principles.**

Terraform + Kubernetes infrastructure that scales from local development to cloud production.

## Overview

This repository contains the infrastructure code for deploying a complete ML platform with:

- **Single cluster architecture** with team isolation (simpler than multi-cluster)
- **GitOps workflow** using ArgoCD for continuous deployment
- **Local development** that mirrors production
- **Security and monitoring** built-in from the start

## Quick Start

```bash
# Clone the repository
git clone https://github.com/gigifokchiman/implement-ml-p.git
cd implement-ml-p

# Follow the New Engineer Runbook for complete setup
# Or for the impatient:
./infrastructure/scripts/deploy-local.sh
```

**→ See [New Engineer Runbook](./docs/NEW-ENGINEER-RUNBOOK.md) for step-by-step instructions**

## Architecture

### Core Design Principles

1. **Single Cluster, Multi-Team**: Use namespaces and RBAC for team isolation instead of multiple clusters
2. **GitOps Everything**: All deployments through ArgoCD, infrastructure as code
3. **Local = Production**: Same tools, same configs, different scale
4. **Kubernetes Native**: Leverage k8s features instead of adding complexity

### Platform Stack

```
┌─────────────────────────────────────────────────┐
│                ML Platform Cluster               │
│                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │  ML Team    │ │ Data Team   │ │  App Team   │ │
│  │             │ │             │ │             │ │
│  │ • Quotas    │ │ • Quotas    │ │ • Quotas    │ │
│  │ • RBAC      │ │ • RBAC      │ │ • RBAC      │ │
│  │ • Isolation │ │ • Isolation │ │ • Isolation │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ │
│                                                 │
│  ┌─────────────────────────────────────────────┐ │
│  │           Shared Platform Services          │ │
│  │  PostgreSQL • Redis • MinIO • Monitoring    │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- Docker Desktop
- Basic command line tools: `kubectl`, `terraform`, `helm`
- Or use our Docker container with everything pre-installed

### Deployment Options

For detailed deployment instructions, see the [New Engineer Runbook](./docs/NEW-ENGINEER-RUNBOOK.md).

**Quick Reference:**
- **Full Platform**: `./infrastructure/scripts/deploy-local.sh` (includes Kubernetes, GitOps, monitoring)
- **Docker Compose**: `docker-compose up -d` (simpler, no Kubernetes)
- **Cloud**: Use terraform environments in `infrastructure/terraform/environments/`

## What's Included

### Infrastructure Layer (Terraform)
- **Kubernetes clusters**: Kind for local, EKS for AWS
- **Databases**: PostgreSQL with automated backups
- **Caching**: Redis for session and ML model caching
- **Storage**: S3-compatible object storage (MinIO locally)
- **Networking**: Ingress, load balancers, service mesh ready

### Platform Layer (Kubernetes)
- **GitOps**: ArgoCD for deployment automation
- **Security**: RBAC, network policies, pod security standards
- **Monitoring**: Prometheus, Grafana, and distributed tracing
- **ML Tools**: Ready for Kubeflow, MLflow, or custom solutions

### Team Isolation
- **Resource Quotas**: CPU, memory, GPU limits per team
- **RBAC**: Team members can only access their namespace
- **Network Policies**: Optional network isolation between teams
- **Cost Attribution**: Labels for tracking resource usage

## Project Structure

```
infrastructure/
├── terraform/                    # Infrastructure as Code
│   ├── environments/            # Environment-specific configs
│   │   ├── local/              # Local Kind cluster
│   │   ├── dev/                # Development AWS
│   │   └── prod/               # Production AWS
│   └── modules/                 # Reusable Terraform modules
├── kubernetes/                   # Kubernetes manifests
│   ├── team-isolation/         # Team namespaces and quotas
│   ├── security/               # Security policies
│   └── monitoring/             # Observability stack
├── scripts/                     # Deployment and management scripts
└── docs/                        # Documentation
```

## Documentation

- [New Engineer Runbook](./docs/NEW-ENGINEER-RUNBOOK.md) - Start here
- [Architecture Overview](./docs/ARCHITECTURE.md) - Design decisions
- [Security Guide](./docs/SECURITY.md) - Security implementation
- [Operations Guide](./docs/OPERATIONS.md) - Day-2 operations

## Common Tasks

See the [New Engineer Runbook](./docs/NEW-ENGINEER-RUNBOOK.md) for detailed instructions on:
- Setting up the platform from scratch
- Deploying applications
- Managing team resources and quotas
- Accessing monitoring dashboards
- Testing security and isolation

## Design Decisions

### Why Single Cluster?
- **Simplicity**: Easier to manage one cluster than many
- **Cost**: Shared control plane and system pods
- **Good Enough**: Namespace isolation works for most use cases
- **Migration Path**: Can split into multiple clusters later if needed

### Why GitOps?
- **Auditability**: All changes tracked in git
- **Reliability**: Declarative state, automatic reconciliation  
- **Developer Experience**: Push code, see it deployed

### Technology Choices
- **Terraform**: Infrastructure as code, cloud agnostic
- **ArgoCD**: Best-in-class GitOps engine
- **Prometheus**: De facto Kubernetes monitoring
- **Kind**: Fast local Kubernetes development

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./tests/run-tests.sh`
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- Issues: [GitHub Issues](https://github.com/gigifokchiman/implement-ml-p/issues)
- Documentation: [Full docs](./docs/_CATALOG.md)

---

Built for ML engineers who want to focus on ML, not infrastructure.