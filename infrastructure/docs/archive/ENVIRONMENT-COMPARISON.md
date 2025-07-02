# Environment Comparison: Local vs Cloud

## Quick Reference

### Core Infrastructure Differences

| Component | Local | Dev/Staging/Prod |
|-----------|-------|------------------|
| **Kubernetes** | Kind cluster in Docker | AWS EKS managed cluster |
| **Container Registry** | Local Docker registry (`localhost:5001`) | AWS ECR repositories |
| **Object Storage** | MinIO container (S3-compatible) | AWS S3 buckets |
| **Database** | PostgreSQL container | AWS RDS (managed PostgreSQL) |
| **Caching** | Redis container | AWS ElastiCache (Redis) |
| **Networking** | Docker bridge network | AWS VPC with subnets |
| **Load Balancer** | Kind port mappings | AWS Application Load Balancer |
| **DNS** | Local resolution | AWS Route53 + ALB |
| **Secrets** | Kubernetes secrets | AWS Secrets Manager integration |
| **Backup** | None (local volumes) | Automated RDS backups |

### Development Experience Differences

| Aspect | Local | Cloud Environments |
|--------|-------|-------------------|
| **Startup Time** | ~2 minutes | ~15-20 minutes |
| **Cost** | $0 (runs on local machine) | $50-500+ per month depending on usage |
| **Internet Required** | No (after initial setup) | Yes (for AWS API calls) |
| **Persistence** | Local volumes (survives restarts) | EBS volumes + RDS (persistent) |
| **Scaling** | Fixed 3-node cluster | Dynamic auto-scaling |
| **Resource Limits** | Limited by local machine | Limited by AWS quotas/budget |
| **Debugging** | Direct container access | CloudWatch logs + kubectl |
| **Data Loss Risk** | High (local machine failure) | Low (AWS managed services) |

### When to Use Each Environment

#### Use Local When:
- ✅ Developing new features
- ✅ Testing application logic
- ✅ Debugging container issues
- ✅ Working offline
- ✅ Learning Kubernetes
- ✅ Rapid iteration cycles
- ✅ No AWS costs desired

#### Use Cloud Environments When:
- ✅ Testing cloud integrations (S3, RDS, etc.)
- ✅ Performance testing with realistic resources
- ✅ Multi-user collaboration
- ✅ CI/CD pipeline validation
- ✅ Production-like data volumes
- ✅ Network policy testing
- ✅ Load balancer configuration
- ✅ SSL/TLS certificate testing

### Configuration Management

#### Local Environment
```yaml
# Uses Kustomize overlay: infrastructure/kubernetes/overlays/local/
# Includes:
- MinIO deployment
- Local Docker registry integration
- PostgreSQL container
- Redis container
- Development-friendly configurations
```

#### Cloud Environments
```yaml
# Uses Kustomize overlays: infrastructure/kubernetes/overlays/{dev,staging,prod}/
# Includes:
- AWS service integrations
- ECR image references
- RDS connection configurations
- S3 bucket references
- Environment-specific scaling policies
```

### Resource Requirements

#### Local Environment
```
Minimum Requirements:
- Docker Desktop installed
- 8GB RAM (16GB recommended)
- 4 CPU cores
- 20GB free disk space

Terraform Providers:
- tehcyx/kind (Kind cluster management)
- kreuzwerker/docker (Docker registry)
- hashicorp/kubernetes (K8s resources)
```

#### Cloud Environments
```
AWS Requirements:
- Valid AWS account with billing enabled
- IAM permissions for EKS, RDS, S3, ECR, VPC
- AWS CLI configured
- kubectl installed

Terraform Providers:
- hashicorp/aws (All AWS resources)
- hashicorp/kubernetes (K8s resources)
- hashicorp/helm (Helm charts)
```

### Data Flow Differences

#### Local Data Flow
```
Developer Machine
├── Kind Cluster (Kubernetes)
│   ├── Application Pods
│   ├── PostgreSQL Pod
│   ├── Redis Pod
│   └── MinIO Pod
├── Local Docker Registry
└── Local Volumes
```

#### Cloud Data Flow
```
AWS Cloud
├── EKS Cluster
│   └── Application Pods
├── RDS (PostgreSQL)
├── ElastiCache (Redis)
├── S3 Buckets
├── ECR Repositories
└── VPC Networking
```

### Common Commands

#### Local Environment
```bash
# Start local development
make dev-kind-up

# Build and push images
docker build -t localhost:5001/app:latest .
docker push localhost:5001/app:latest

# Deploy applications
kubectl apply -k infrastructure/kubernetes/overlays/local

# Access services
kubectl port-forward svc/frontend 8080:80
```

#### Cloud Environments
```bash
# Start cloud development
make dev-aws-up

# Build and push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <ecr-url>
docker build -t <ecr-url>/app:latest .
docker push <ecr-url>/app:latest

# Deploy applications
kubectl apply -k infrastructure/kubernetes/overlays/dev

# Access via load balancer
kubectl get ingress
```

### Migration Strategy

The environments are designed to provide a smooth migration path:

1. **Local Development** → Start here for all feature development
2. **Dev Environment** → Test cloud integrations and dependencies
3. **Staging Environment** → Validate with production-like resources
4. **Prod Environment** → Deploy to live users

Each environment maintains the same application interface while providing increasing levels of production readiness and AWS service integration.