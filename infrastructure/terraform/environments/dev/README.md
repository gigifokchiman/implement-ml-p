# Unified Development Environment

This directory provides a unified Terraform configuration that can deploy either:

1. **Kind Cluster** (local development)
2. **AWS EKS** (cloud development)

## Quick Start

### Option 1: Local Development with Kind

```bash
# Start Kind cluster with local registry
make dev-kind-up

# Build and push your images  
make dev-build-push

# Check status
make dev-status

# View logs
make dev-logs

# Stop when done
make dev-kind-down
```

### Option 2: AWS Cloud Development

```bash
# Start AWS EKS cluster
make dev-aws-up

# Build and push to ECR
make dev-build-push

# Check status
make dev-status

# Stop when done
make dev-aws-down
```

## Architecture

### Kind Cluster Mode (`use_kind_cluster = true`)

**Infrastructure:**

- Multi-node Kind cluster (1 control-plane + 2 workers)
- Local Docker registry on `localhost:5001`
- Port forwarding for web access (`8080` → `80`)
- Shared Docker network for registry connectivity

**Storage:**

- MinIO for S3-compatible object storage
- Local persistent volumes
- Development-grade configurations

**Image Registry:**

- Local Docker registry container
- No authentication required
- Images: `localhost:5001/ml-platform/{service}:dev`

### AWS EKS Mode (`use_kind_cluster = false`)

**Infrastructure:**

- AWS EKS cluster with managed node groups
- AWS VPC with private/public subnets
- Application Load Balancer for ingress
- RDS PostgreSQL for metadata
- ElastiCache Redis for caching

**Storage:**

- AWS S3 buckets for object storage
- EBS volumes for persistent storage
- Production-grade backup and encryption

**Image Registry:**

- AWS ECR repositories
- IAM authentication via IRSA
- Images: `{account}.dkr.ecr.{region}.amazonaws.com/ml-platform/{service}:dev`

## Configuration Variables

| Variable            | Description             | Default           | Kind Mode | AWS Mode |
|---------------------|-------------------------|-------------------|-----------|----------|
| `use_kind_cluster`  | Use Kind instead of EKS | `false`           | `true`    | `false`  |
| `kind_cluster_name` | Kind cluster name       | `ml-platform-dev` | ✓         | -        |
| `cluster_name`      | EKS cluster name        | `ml-platform`     | -         | ✓        |
| `region`            | AWS region              | `us-west-2`       | -         | ✓        |
| `vpc_cidr`          | VPC CIDR block          | `10.0.0.0/16`     | -         | ✓        |

## Usage Examples

### Deploy Kind Cluster

```bash
cd infrastructure/terraform/environments/dev
terraform apply -var="use_kind_cluster=true"
```

### Deploy AWS EKS

```bash
cd infrastructure/terraform/environments/dev
terraform apply -var="use_kind_cluster=false"
```

### Use Custom Cluster Name

```bash
terraform apply -var="use_kind_cluster=true" -var="kind_cluster_name=my-dev-cluster"
```

## Outputs

### Kind Mode Outputs

```bash
terraform output kind_cluster_info
# Returns:
# {
#   "endpoint" = "https://127.0.0.1:xxxx"
#   "kubeconfig_path" = "/path/to/kubeconfig"
#   "local_registry_url" = "localhost:5001"
#   "name" = "ml-platform-dev"
# }

terraform output development_urls  
# Returns:
# {
#   "frontend" = "http://localhost:8080"
#   "kubernetes_api" = "https://127.0.0.1:xxxx"
#   "registry_ui" = "http://localhost:5001/v2/_catalog"
# }
```

### AWS Mode Outputs

```bash
terraform output ecr_repositories
# Returns:
# {
#   "backend" = "123456789012.dkr.ecr.us-west-2.amazonaws.com/ml-platform/backend"
#   "frontend" = "123456789012.dkr.ecr.us-west-2.amazonaws.com/ml-platform/frontend"  
# }

terraform output development_urls
# Returns:
# {
#   "ecr_login" = "aws ecr get-login-password ..."
#   "frontend" = "https://ml-platform-dev-alb-xxx.us-west-2.elb.amazonaws.com"
# }
```

## Kubernetes Manifests

The Terraform configuration automatically applies the appropriate Kubernetes manifests:

- **Kind Mode**: Uses `infrastructure/kubernetes/overlays/dev-kind`
- **AWS Mode**: Uses `infrastructure/kubernetes/overlays/dev` (if exists) or base configuration

### Manifest Differences

| Component     | Kind Mode                          | AWS Mode                                         |
|---------------|------------------------------------|--------------------------------------------------|
| Images        | `localhost:5001/ml-platform/*:dev` | `*.dkr.ecr.*.amazonaws.com/ml-platform/*:latest` |
| Storage       | MinIO + local PVs                  | S3 + EBS                                         |
| Networking    | NodePort (30080)                   | ALB Ingress                                      |
| Registry Auth | None                               | ECR/IAM                                          |

## Development Workflow

### 1. Choose Your Environment

**Local/Offline Development:**

```bash
make dev-kind-up
```

**Cloud Development:**

```bash  
make dev-aws-up
```

### 2. Build and Deploy

```bash
# Automatically detects whether you're using Kind or AWS
make dev-build-push
```

### 3. Develop and Test

```bash
# Check pod status
make dev-status

# View application logs
make dev-logs

# Access your application
# Kind: http://localhost:8080
# AWS: Check terraform output development_urls
```

### 4. Clean Up

```bash
# For Kind
make dev-kind-down

# For AWS  
make dev-aws-down
```

## Prerequisites

### For Kind Mode

- Docker
- Kind CLI (`go install sigs.k8s.io/kind@latest`)
- kubectl
- Terraform

### For AWS Mode

- AWS CLI configured
- kubectl
- Terraform
- AWS credentials with appropriate permissions

## Troubleshooting

### Kind Cluster Issues

```bash
# Check Kind clusters
kind get clusters

# Check Kind cluster status
kubectl cluster-info --context kind-ml-platform-dev

# Check registry connectivity
curl http://localhost:5001/v2/_catalog
```

### AWS Issues

```bash
# Check EKS cluster
aws eks describe-cluster --name ml-platform-dev

# Update kubeconfig
aws eks update-kubeconfig --name ml-platform-dev --region us-west-2

# Check ECR repositories
aws ecr describe-repositories
```

### Registry Issues

```bash
# Kind: Check local registry
docker ps | grep registry

# AWS: Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
```

## Cost Optimization

### Kind Mode

- **Cost**: $0 (local only)
- **Resources**: Uses local Docker/CPU/memory
- **Suitable for**: Feature development, testing, demos

### AWS Mode

- **Cost**: ~$50-100/month (EKS cluster + nodes + RDS + ALB)
- **Resources**: t3.medium nodes, db.t3.micro RDS
- **Suitable for**: Integration testing, staging, team collaboration

## Security Notes

### Kind Mode

- Local development only
- No authentication on registry
- Minimal security controls
- Not suitable for sensitive data

### AWS Mode

- Production-grade security
- IAM-based authentication
- VPC isolation
- Encrypted storage
- Suitable for realistic testing
