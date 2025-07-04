# data Cluster

Local development cluster for the data application.

## Configuration

- **Cluster name**: data-local
- **HTTP port**: 8100
- **HTTPS port**: 8443

## Usage

```bash
# Initialize and apply
terraform init
terraform apply

# Switch to cluster context
kubectl config use-context kind-data-local

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Access services (port-forward examples)
kubectl port-forward -n database svc/postgres 5432:5432
kubectl port-forward -n cache svc/redis 6379:6379
kubectl port-forward -n storage svc/minio 9001:9000

# Clean up
terraform destroy
kind delete cluster --name data-local
```

## Application URLs

- **Application**: http://localhost:8100
- **MinIO**: http://localhost:9001 (admin/changeme123)
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

## Customization

Edit `terraform.tfvars` to customize:
- Database credentials
- Storage buckets
- Cache settings
- Resource limits

## Generated on Thu Jul  3 03:27:37 PDT 2025
