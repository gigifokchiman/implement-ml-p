# ML Platform Infrastructure

Clean, organized infrastructure for the ML Platform using Terraform and Kubernetes.

## Structure

```
infrastructure/
├── terraform/                 # Infrastructure provisioning
│   ├── modules/              # Reusable Terraform modules (future)
│   └── environments/         # Environment-specific configurations
│       ├── dev/              # Development environment
│       ├── staging/          # Staging environment
│       └── prod/             # Production environment
├── kubernetes/               # Application deployment (Kustomize)
│   ├── base/                # Shared base configurations
│   │   ├── apps/            # Application manifests
│   │   ├── network/         # Ingress, services
│   │   ├── security/        # RBAC, secrets
│   │   └── storage/         # Storage classes, PVCs
│   └── overlays/            # Environment-specific overlays
│       ├── local/           # Kind/local development
│       ├── dev/             # AWS EKS development
│       ├── staging/         # AWS EKS staging
│       └── prod/            # AWS EKS production
└── scripts/                 # Deployment automation
    ├── deploy.sh            # Unified deployment script
    └── generate-certs.sh    # Certificate generation
```

## Quick Start

### Local Development (Kind)

```bash
# Deploy everything locally
./scripts/deploy.sh -e local

# Access the platform
echo "127.0.0.1 ml-platform.local api.ml-platform.local minio.ml-platform.local" | sudo tee -a /etc/hosts
open http://ml-platform.local:30080
```

### AWS Environments

```bash
# Deploy to development
./scripts/deploy.sh -e dev

# Deploy only infrastructure to production
./scripts/deploy.sh -e prod -c terraform

# Deploy only applications to staging
./scripts/deploy.sh -e staging -c kubernetes --skip-terraform
```

## Environment Differences

| Environment | Infrastructure | Node Groups    | Storage    | High Availability |
|-------------|----------------|----------------|------------|-------------------|
| **local**   | Kind cluster   | N/A            | local-path | No                |
| **dev**     | EKS (2 AZ)     | General only   | gp2        | Minimal           |
| **staging** | EKS (3 AZ)     | General + Data | gp3        | Partial           |
| **prod**    | EKS (3 AZ)     | All node types | gp3        | Full              |

## Components

### Terraform Infrastructure

- **VPC**: Multi-AZ networking with public/private subnets
- **EKS**: Kubernetes cluster with managed node groups
- **RDS**: PostgreSQL for metadata storage
- **ElastiCache**: Redis for caching (staging/prod)
- **S3**: Object storage buckets
- **ALB**: Application Load Balancer (prod)

### Kubernetes Applications

- **Frontend**: React/Next.js web application
- **Backend**: API service
- **MinIO**: Object storage for data lake
- **Ingress**: NGINX ingress controller

## Security

- All containers run as non-root users
- Read-only root filesystems where possible
- Network policies for pod communication
- RBAC for service accounts
- TLS encryption for ingress traffic

## Deployment Options

### Full Deployment

```bash
./scripts/deploy.sh -e prod
```

### Infrastructure Only

```bash
./scripts/deploy.sh -e prod -c terraform
```

### Applications Only

```bash
./scripts/deploy.sh -e prod -c kubernetes --skip-terraform
```

### Dry Run

```bash
./scripts/deploy.sh -e prod -d
```

## Certificate Management

Generate certificates for any environment:

```bash
# Local development
./scripts/generate-certs.sh local

# Production
./scripts/generate-certs.sh prod
```

## Migration from Legacy Structure

This infrastructure replaces the messy legacy structure that had:

- 36+ duplicate YAML files
- 3 different deployment methods
- Mixed environment/tool concerns
- Inconsistent certificate management

### Key Improvements

1. **Single deployment method**: Kustomize with environment overlays
2. **Unified certificate management**: One script for all environments
3. **Clear separation**: Terraform for infrastructure, Kubernetes for applications
4. **Environment consistency**: Same base configs with environment-specific patches
5. **No duplication**: DRY principle throughout

## Troubleshooting

### Local Development

```bash
# Check Kind cluster
kind get clusters

# Check ingress controller
kubectl get pods -n ingress-nginx

# Port forward if ingress doesn't work
kubectl port-forward -n ml-platform svc/frontend 3000:3000
```

### AWS Environments

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name ml-platform-prod

# Check node groups
kubectl get nodes -o wide

# Check ingress
kubectl get ingress -n ml-platform
```

### Common Issues

1. **"storageClass not found"**: Update storage class in environment overlay
2. **"certificate errors"**: Regenerate certificates with `generate-certs.sh`
3. **"ingress not working"**: Check ingress controller is running
4. **"pods pending"**: Check node resources and taints

## Simplified Deployment

The infrastructure uses a simple, startup-friendly approach with 3 core tools:

**Stack:**

- **Terraform**: Cloud infrastructure (S3, RDS, EKS, etc.)
- **Kustomize**: Environment-specific Kubernetes configurations
- **GitHub Actions**: CI/CD pipeline for automated deployments

**Quick Deployment:**

```bash
# Deploy everything locally (Kind cluster)
./scripts/deploy.sh -e local

# Deploy to development
make deploy-dev

# Deploy to production (with confirmation)
make deploy-prod
```

**Manual Deployment:**

```bash
# Deploy infrastructure
cd infrastructure/terraform/environments/prod
terraform apply

# Deploy applications
kubectl apply -k infrastructure/kubernetes/overlays/prod
```

## Next Steps

1. Add monitoring with Prometheus/Grafana
2. Add secret management with External Secrets Operator
3. Set up backup strategies for persistent data
4. Implement disaster recovery procedures
5. Consider ArgoCD when team grows (5+ people)
