# Infrastructure Architecture Guide

## Overview

This infrastructure uses a **two-layer architecture** with clear separation of concerns:

### Layer 1: Infrastructure (Terraform)

Manages the foundational cloud and compute resources.

### Layer 2: Applications (Kustomize)

Manages application deployments and configurations.

## Architecture Principles

### 🎯 **Separation of Concerns**

- **Terraform**: Infrastructure provisioning (clusters, databases, networks)
- **Kustomize**: Application deployment and configuration management

### 🌍 **Cloud Agnostic Design**

- Local development mimics production AWS services
- Same application code works across all environments
- Environment-specific configuration via overlays

### 🔄 **Environment Parity**

- **Local**: Kind + Docker containers simulating AWS services
- **AWS**: Real managed services (EKS, RDS, S3, etc.)
- **Application Layer**: Identical across all environments

## Directory Structure

```
infrastructure/
├── terraform/                    # Layer 1: Infrastructure
│   ├── environments/
│   │   ├── local/               # Kind cluster + local services
│   │   ├── dev/                 # AWS dev environment
│   │   ├── staging/             # AWS staging environment
│   │   └── prod/                # AWS production environment
│   └── modules/
│       ├── local-services/      # Local AWS service equivalents
│       ├── aws-eks/            # AWS EKS cluster
│       ├── aws-rds/            # AWS RDS database
│       └── aws-storage/        # AWS S3 and related services
│
├── kubernetes/                   # Layer 2: Applications
│   ├── base/                    # Base Kustomize configurations
│   │   ├── backend/            # ML platform backend service
│   │   ├── frontend/           # ML platform frontend service
│   │   ├── ml-jobs/            # ML training and processing jobs
│   │   └── monitoring/         # Observability stack
│   └── overlays/
│       ├── local/              # Local development overrides
│       ├── dev/                # Development environment config
│       ├── staging/            # Staging environment config
│       └── prod/               # Production environment config
│
└── tests/                       # Test suites for both layers
    ├── terraform/              # Infrastructure tests
    └── kubernetes/             # Application tests
```

## Deployment Flow

### 1. Infrastructure Provisioning (Terraform)

```bash
# Local development
cd terraform/environments/local
terraform apply

# AWS environments  
cd terraform/environments/prod
terraform apply
```

### 2. Application Deployment (Kustomize)

```bash
# Deploy to local
kubectl apply -k kubernetes/overlays/local

# Deploy to production
kubectl apply -k kubernetes/overlays/prod
```

## Environment Configuration Strategy

### Local Development

- **Infrastructure**: Kind cluster + PostgreSQL/Redis/MinIO containers
- **Applications**: Development builds with debug logging
- **Storage**: Local persistent volumes
- **Networking**: NodePort services for easy access

### Production

- **Infrastructure**: AWS EKS + RDS + ElastiCache + S3
- **Applications**: Production builds with security hardening
- **Storage**: AWS EBS volumes
- **Networking**: LoadBalancer services with TLS

## Service Mapping

| Component      | Local (Docker/K8s)    | AWS Production          |
|----------------|-----------------------|-------------------------|
| **Cluster**    | Kind                  | EKS                     |
| **Database**   | PostgreSQL container  | RDS PostgreSQL          |
| **Cache**      | Redis container       | ElastiCache Redis       |
| **Storage**    | MinIO S3-compatible   | S3                      |
| **Registry**   | Local Docker registry | ECR                     |
| **Ingress**    | NGINX Ingress         | ALB + ACM               |
| **Monitoring** | Metrics Server        | CloudWatch + Prometheus |

## Configuration Management

### Environment Variables Pattern

Applications use the same environment variables across all environments:

```yaml
# Application configuration (same everywhere)
DATABASE_URL: postgresql://user:pass@host:5432/db
REDIS_URL: redis://host:6379
S3_ENDPOINT: ${S3_ENDPOINT}  # Environment-specific
```

### Kustomize Patches

Environment-specific customizations:

```yaml
# overlays/local/kustomization.yaml
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: backend
    spec:
      template:
        spec:
          containers:
          - name: app
            env:
            - name: S3_ENDPOINT
              value: "http://minio:9000"
            - name: S3_FORCE_PATH_STYLE  # MinIO requires this
              value: "true"
```

## Best Practices

### 🏗️ **Infrastructure (Terraform)**

1. **Immutable Infrastructure**: Recreate rather than modify
2. **State Management**: Remote state with locking
3. **Module Reusability**: Shared modules across environments
4. **Security**: Secrets in managed services, not code

### 🚀 **Applications (Kustomize)**

1. **Base + Overlays**: DRY principle with environment-specific patches
2. **ConfigMaps**: Environment configuration
3. **Secrets**: Sensitive data management
4. **Resource Limits**: Prevent resource exhaustion

### 🔒 **Security**

1. **Network Policies**: Service isolation
2. **RBAC**: Least privilege access
3. **Image Security**: Scan for vulnerabilities
4. **Secret Rotation**: Regular credential updates

### 📊 **Monitoring**

1. **Health Checks**: Liveness and readiness probes
2. **Metrics**: Resource usage and business metrics
3. **Logging**: Structured logging with correlation IDs
4. **Alerting**: Proactive issue detection

## Migration Path

### Local → AWS

1. **Update environment variables** (S3 endpoint, etc.)
2. **Switch Kustomize overlay** (local → prod)
3. **Deploy with same commands** - no application changes needed

### Development Workflow

1. **Develop locally** with full stack
2. **Test with realistic data** volumes
3. **Deploy to staging** for integration testing
4. **Promote to production** with confidence

## Troubleshooting

### Common Issues

1. **Resource Limits**: Check quotas and limits
2. **Network Connectivity**: Verify service discovery
3. **Storage Issues**: Check PVC and storage classes
4. **Image Pull**: Verify registry access

### Debug Commands

```bash
# Check infrastructure
terraform plan
kubectl get nodes,pods,svc

# Check applications  
kustomize build overlays/local
kubectl logs -l app=backend
```
