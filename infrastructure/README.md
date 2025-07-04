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

### Platform Stack & Environments

#### Environment Strategy

```
🏠 Local Development          ☁️ Cloud Environments
┌─────────────────────┐      ┌─────────────────────┐
│   Kind Cluster      │      │   AWS EKS Cluster   │
├─────────────────────┤      ├─────────────────────┤
│ • Single Node       │      │ • Multi-AZ (2-3)    │
│ • Docker Registry   │      │ • ECR Registry      │
│ • MinIO Storage     │      │ • S3 Storage        │
│ • Local PostgreSQL  │      │ • RDS PostgreSQL    │
│ • Local Redis       │      │ • ElastiCache Redis │
└─────────────────────┘      └─────────────────────┘
```

#### Environment Configurations

| Environment | Location                          | Purpose                   | Key Differences                             |
|-------------|-----------------------------------|---------------------------|---------------------------------------------|
| **local**   | `terraform/environments/local/`   | Developer laptops         | Kind cluster, MinIO, containerized services |
| **dev**     | `terraform/environments/dev/`     | Integration testing       | EKS 2-AZ, smaller instances, reduced HA     |
| **staging** | `terraform/environments/staging/` | Pre-production validation | EKS 3-AZ, production-like, synthetic data   |
| **prod**    | `terraform/environments/prod/`    | Production workloads      | EKS 3-AZ, full HA, backup, monitoring       |

#### Platform Architecture

```
┌─────────────────────────────────────────────────┐
│                ML Platform Cluster               │
│                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │  ML Team    │ │ Data Team   │ │  App Team   │ │
│  │             │ │             │ │             │ │
│  │ • 20 CPU    │ │ • 16 CPU    │ │ • 8 CPU     │ │
│  │ • 64GB RAM  │ │ • 48GB RAM  │ │ • 24GB RAM  │ │
│  │ • 4 GPUs    │ │ • 1TB Store │ │ • 200GB     │ │
│  │ • Notebooks │ │ • Pipelines │ │ • APIs      │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ │
│                                                 │
│  ┌─────────────────────────────────────────────┐ │
│  │           Shared Platform Services          │ │
│  │                                             │ │
│  │  📊 Database    💾 Cache     🗄️ Storage    │ │
│  │  PostgreSQL    Redis        MinIO/S3       │ │
│  │                                             │ │
│  │  📈 Monitoring  🔒 Security  🚀 GitOps     │ │
│  │  Prometheus    RBAC/TLS     ArgoCD        │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

#### Service Mapping by Environment

| Component      | Local (Kind)     | Dev/Staging (AWS)       | Production (AWS)      |
|----------------|------------------|-------------------------|-----------------------|
| **Compute**    | Kind nodes       | EKS managed nodes       | EKS with autoscaling  |
| **Database**   | PostgreSQL pod   | RDS PostgreSQL          | RDS Multi-AZ          |
| **Cache**      | Redis pod        | ElastiCache             | ElastiCache cluster   |
| **Storage**    | MinIO + local PV | S3 buckets              | S3 with versioning    |
| **Registry**   | Local registry   | ECR                     | ECR with scanning     |
| **Ingress**    | NodePort         | ALB                     | ALB + WAF             |
| **DNS**        | /etc/hosts       | Route53                 | Route53 + CDN         |
| **Secrets**    | K8s secrets      | Secrets Manager         | Secrets Manager + KMS |
| **Monitoring** | Basic Prometheus | CloudWatch + Prometheus | Full observability    |

#### Environment Promotion Flow

```
Developer Laptop → Dev Cluster → Staging Cluster → Production
     (local)         (dev)         (staging)         (prod)
        ↓              ↓               ↓                ↓
   Kind + MinIO    EKS + S3      EKS + S3        EKS + S3
   Fast iteration  Integration   Load testing    Real traffic
```

#### Key Environment Features

**Local Development**

- **Fast feedback**: 2-minute cluster creation
- **Offline capable**: Everything runs locally
- **Resource efficient**: Single node cluster
- **Cost**: $0 (runs on laptop)

**Dev Environment**

- **Shared by team**: Multiple developers
- **Automated testing**: CI/CD pipelines
- **Lower resources**: t3.medium instances
- **Cost**: ~$200/month

**Staging Environment**

- **Production mirror**: Same config as prod
- **Performance testing**: Load testing ready
- **Security scanning**: Full security suite
- **Cost**: ~$800/month

**Production Environment**

- **High availability**: Multi-AZ deployment
- **Auto-scaling**: Based on workload
- **Full monitoring**: Metrics, logs, traces
- **Cost**: ~$2000-5000/month (varies)

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
