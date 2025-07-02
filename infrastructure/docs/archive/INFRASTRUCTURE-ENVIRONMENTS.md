# Infrastructure Environment Configuration

This document outlines the different infrastructure environments and their configurations in the ML Platform project.

## Environment Overview

The ML Platform supports four distinct environments, each designed for specific use cases:

- **Local**: Development environment using Kind (Kubernetes in Docker)
- **Dev**: AWS-based development environment with cost optimizations
- **Staging**: AWS-based pre-production environment
- **Prod**: AWS-based production environment with high availability

## Environment Comparison

### Infrastructure Provider

| Environment | Provider | Purpose |
|-------------|----------|---------|
| Local | Kind + Docker | Local development without AWS costs |
| Dev | AWS | Cloud development and testing |
| Staging | AWS | Pre-production validation |
| Prod | AWS | Production workloads |

### Kubernetes Cluster Configuration

| Component | Local | Dev | Staging | Prod |
|-----------|-------|-----|---------|------|
| **Cluster Type** | Kind cluster | AWS EKS | AWS EKS | AWS EKS |
| **Cluster Version** | Latest Kind default | 1.28 | 1.28 | 1.28 |
| **Nodes** | 3 nodes (1 control-plane, 2 workers) | 1-3 nodes | 2-6 nodes | 1-10 nodes (general) |
| **Instance Types** | Docker containers | t3.medium | m5.large | m5.large (general), c5.2xlarge (data), m5.xlarge (ml), g4dn.xlarge (gpu) |
| **High Availability** | Single cluster | Single AZ | Multi-AZ | Multi-AZ |
| **Auto Scaling** | Fixed | 1-3 nodes | 2-6 nodes | Complex scaling per node group |

### Node Groups

#### Local Environment
- **All workloads**: Single Kind cluster handles all workloads (no node groups)

#### Dev Environment
- **General**: 1-3 t3.medium nodes for general workloads

#### Staging Environment
- **General**: 2-6 m5.large nodes for general workloads
- **Data Processing**: 0-8 c5.xlarge nodes with taints for data workloads

#### Prod Environment
- **General**: 1-10 m5.large nodes for general workloads
- **Data Processing**: 0-20 c5.2xlarge nodes with taints for data workloads
- **ML Workload**: 0-15 m5.xlarge/m5.2xlarge nodes with taints for ML workloads
- **GPU Nodes**: 0-5 g4dn.xlarge nodes with GPU taints for training/inference

### Container Registry

| Environment | Registry Type | Configuration | Access |
|-------------|---------------|---------------|--------|
| Local | Docker Registry | `localhost:5001` | dev:dev123 |
| Dev | AWS ECR | ml-platform/backend, ml-platform/frontend | AWS IAM |
| Staging | AWS ECR | ml-platform/backend, ml-platform/frontend | AWS IAM |
| Prod | AWS ECR | ml-platform/backend, ml-platform/frontend | AWS IAM |

### Storage Configuration

#### Object Storage
| Environment | Type | Purpose | Buckets |
|-------------|------|---------|---------|
| Local | MinIO | S3-compatible local storage | Via Kustomize overlay |
| Dev | AWS S3 | Cloud object storage | ml-artifacts, data-lake |
| Staging | AWS S3 | Cloud object storage | ml-artifacts, data-lake, model-registry |
| Prod | AWS S3 | Cloud object storage | ml-artifacts, data-lake, model-registry |

#### Database (Metadata)
| Environment | Type | Instance | Storage | Backup |
|-------------|------|----------|---------|--------|
| Local | PostgreSQL | Container | Local volume | None |
| Dev | AWS RDS | db.t3.micro | 20-50 GB | 7 days |
| Staging | AWS RDS | db.t3.small | 20-100 GB | 14 days |
| Prod | AWS RDS | db.r6g.large | 20-100 GB | 30 days |

#### Caching
| Environment | Type | Instance | Configuration |
|-------------|------|----------|---------------|
| Local | Redis | Container | Local volume |
| Dev | None | - | Not configured |
| Staging | AWS ElastiCache | cache.t3.small | Single node |
| Prod | AWS ElastiCache | cache.r6g.large | Single node |

### Networking

#### VPC Configuration
| Environment | VPC | Subnets | NAT Gateway |
|-------------|-----|---------|-------------|
| Local | Docker network | Kind network | Not applicable |
| Dev | 10.0.0.0/16 | 2 AZs | Single (cost optimization) |
| Staging | 10.1.0.0/16 | 3 AZs | Multi-AZ |
| Prod | 10.0.0.0/16 | All AZs | Multi-AZ |

#### Load Balancer
| Environment | Type | Configuration |
|-------------|------|---------------|
| Local | Kind port mappings | HTTP: 8080, HTTPS: 8443 |
| Dev | None | Direct service access |
| Staging | None | Direct service access |
| Prod | AWS ALB | HTTP/HTTPS with SSL termination |

### Security & Compliance

#### Backup & Recovery
| Environment | RDS Backup | Deletion Protection | Final Snapshot |
|-------------|------------|-------------------|----------------|
| Local | None | No | No |
| Dev | 7 days | No | Skip |
| Staging | 14 days | No | Skip |
| Prod | 30 days | Yes | Required |

#### Tagging
All environments use consistent tagging:
```hcl
common_tags = {
  "Environment" = "<environment>"
  "Project"     = "ml-platform"
  "ManagedBy"   = "terraform"
}
```

### Development Workflow

#### Local Development
```bash
# Start Kind cluster
make dev-kind-up

# Build and push to local registry
make dev-build-push

# Deploy applications
kubectl apply -k infrastructure/kubernetes/overlays/local

# Access applications
# Frontend: http://localhost:8080
# Registry: http://localhost:5001/v2/_catalog
```

#### Cloud Development
```bash
# Start AWS EKS (dev environment)
make dev-aws-up

# Build and push to ECR
make dev-build-push

# Deploy applications
kubectl apply -k infrastructure/kubernetes/overlays/dev
```

### Cost Optimization

#### Local Environment
- **Zero AWS costs** - runs entirely on local machine
- **Minimal resource usage** - single Kind cluster
- **No persistent storage costs** - local volumes only

#### Dev Environment
- **Single NAT Gateway** - cost optimization
- **Smaller instances** - t3.medium nodes
- **Minimal RDS** - db.t3.micro
- **No ElastiCache** - to reduce costs
- **Skip final snapshots** - faster teardown

#### Staging Environment
- **Balanced resources** - production-like but smaller
- **Multi-AZ for reliability** - but smaller instances
- **Moderate backup retention** - 14 days

#### Prod Environment
- **High availability** - multi-AZ everything
- **Performance instances** - r6g.large for RDS/ElastiCache
- **Comprehensive backup** - 30-day retention
- **Multiple node groups** - specialized workloads
- **GPU support** - g4dn instances for ML workloads
- **SSL termination** - ALB with ACM certificates

### Environment Selection Guide

| Use Case | Recommended Environment |
|----------|------------------------|
| Local development | Local |
| Feature development | Dev |
| Integration testing | Dev |
| Pre-release validation | Staging |
| Load testing | Staging |
| Production traffic | Prod |
| ML model training | Prod (GPU nodes) |
| Data processing | Staging/Prod (data nodes) |

### Migration Path

1. **Develop locally** using Kind cluster
2. **Test in dev** environment for cloud integration
3. **Validate in staging** for production-like testing
4. **Deploy to prod** for live workloads

This architecture ensures a smooth development experience while maintaining cost efficiency and production readiness.