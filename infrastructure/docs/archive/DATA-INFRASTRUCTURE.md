# Data Infrastructure Guide

This guide explains the data infrastructure components in the ML Platform, focusing on object storage and data lake capabilities.

## Overview

The data infrastructure provides:
- **Object Storage**: MinIO for S3-compatible storage
- **Data Lake**: Foundation for Apache Iceberg tables
- **Analytics Workloads**: Dedicated namespace for data processing
- **Secure Access**: TLS and authentication for data services

## Components

### MinIO Object Storage

MinIO provides S3-compatible object storage for the data lake and general file storage needs.

#### Features
- **S3 API Compatibility**: Works with existing S3 tools and libraries
- **Web Console**: Browser-based management interface
- **High Availability**: PodDisruptionBudget and anti-affinity rules
- **Security**: Network policies and secure authentication
- **Monitoring**: Prometheus metrics integration

#### Configuration
- **API Port**: 9000 (S3 API)
- **Console Port**: 9001 (Web interface)
- **Storage**: 8Gi persistent volume
- **Node Affinity**: Prefers storage-type nodes

### Networking and Access

#### Internal Access
- **API Endpoint**: `iceberg-minio.analytics.svc.cluster.local:9000`
- **Console Endpoint**: `iceberg-minio.analytics.svc.cluster.local:9001`

#### External Access (via Ingress)
- **API**: `https://minio.ml-platform.local`
- **Console**: `https://minio-console.ml-platform.local`

## Deployment

### Automatic Deployment
Data components are automatically installed during cluster setup:

```bash
# Development cluster with data components
make setup-cluster

# Production cluster with data components
make setup-cluster-prod
```

### Manual Deployment
Install only data components:

```bash
# Install data infrastructure
make install-data-components

# Or use kubectl directly
kubectl apply -k infrastructure/kubernetes/base/data/
```

## Configuration Details

### File Organization
```
infrastructure/kubernetes/base/data/
├── minio.yaml              # Main MinIO deployment
├── minio-ingress.yaml      # External access configuration
└── kustomization.yaml      # Kustomize configuration
```

### Namespace Structure
- **analytics**: Dedicated namespace for all data infrastructure
- **Labels**: `component=data-infrastructure`, `tier=data`

### Security Configuration

#### Authentication
- **MinIO Credentials**: admin/1bQ8PejOZm (stored in Kubernetes secret)
- **Console Access**: Basic auth via ingress (admin/password)
- **TLS**: Self-signed certificates for HTTPS access

#### Network Security
- **NetworkPolicy**: Restricts traffic to required ports only
- **SecurityContext**: Non-root user, read-only filesystem
- **Capabilities**: Dropped ALL Linux capabilities

### Storage Configuration

#### PersistentVolume
- **Size**: 8Gi (configurable)
- **Access Mode**: ReadWriteOnce
- **Storage Class**: local-path (for Kind clusters)

#### Volume Mounts
- **Data**: `/bitnami/minio/data` (persistent)
- **Temp**: `/tmp` (ephemeral)
- **App Temp**: `/opt/bitnami/minio/tmp` (ephemeral)
- **MC Config**: `/.mc` (ephemeral)

## Usage Examples

### Accessing MinIO Console
1. **Add to /etc/hosts**:
   ```
   127.0.0.1 minio-console.ml-platform.local
   ```

2. **Navigate to**: `https://minio-console.ml-platform.local`

3. **Login**: admin/password (basic auth), then admin/1bQ8PejOZm (MinIO)

### Using MinIO API

#### Python Example
```python
from minio import Minio

# Create client
client = Minio(
    "minio.ml-platform.local",
    access_key="admin",
    secret_key="1bQ8PejOZm",
    secure=True
)

# Create bucket
client.make_bucket("datalake")

# Upload file
client.fput_object("datalake", "data.csv", "/path/to/data.csv")
```

#### AWS CLI Example
```bash
# Configure AWS CLI
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key 1bQ8PejOZm

# Use MinIO endpoint
aws --endpoint-url https://minio.ml-platform.local s3 ls
aws --endpoint-url https://minio.ml-platform.local s3 mb s3://datalake
```

### Iceberg Integration

MinIO serves as the underlying storage for Apache Iceberg tables:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("IcebergExample") \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.iceberg.type", "hadoop") \
    .config("spark.sql.catalog.iceberg.warehouse", "s3a://datalake/warehouse/") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://iceberg-minio.analytics.svc.cluster.local:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "admin") \
    .config("spark.hadoop.fs.s3a.secret.key", "1bQ8PejOZm") \
    .getOrCreate()
```

## Monitoring and Observability

### Health Checks
- **Liveness Probe**: HTTP GET `/minio/health/live`
- **Readiness Probe**: TCP socket check on port 9000

### Metrics
MinIO exposes Prometheus metrics on the API port with public auth type.

### Logs
```bash
# View MinIO logs
kubectl logs -n analytics deployment/iceberg-minio

# Follow logs
kubectl logs -n analytics deployment/iceberg-minio -f
```

## Troubleshooting

### Common Issues

#### 1. PVC Not Bound
```bash
# Check PVC status
kubectl get pvc -n analytics

# Check storage class
kubectl get storageclass

# Ensure local-path provisioner is installed
kubectl get pods -n local-path-storage
```

#### 2. MinIO Not Starting
```bash
# Check pod events
kubectl describe pod -n analytics -l app.kubernetes.io/name=minio

# Check logs
kubectl logs -n analytics deployment/iceberg-minio
```

#### 3. Ingress Not Working
```bash
# Check ingress status
kubectl get ingress -n analytics

# Check ingress controller
kubectl get pods -n ingress-nginx

# Verify TLS secret
kubectl get secret minio-tls-secret -n analytics
```

### Debug Commands
```bash
# Port forward for direct access
kubectl port-forward -n analytics svc/iceberg-minio 9000:9000 9001:9001

# Exec into pod
kubectl exec -it -n analytics deployment/iceberg-minio -- /bin/bash

# Check network connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- /bin/sh
# curl http://iceberg-minio.analytics.svc.cluster.local:9000/minio/health/live
```

## Scaling and Performance

### Vertical Scaling
Adjust resource limits in `minio.yaml`:
```yaml
resources:
  limits:
    cpu: 1000m      # Increase CPU
    memory: 1Gi     # Increase memory
  requests:
    cpu: 500m
    memory: 512Mi
```

### Storage Scaling
Increase PVC size (if storage class supports expansion):
```bash
kubectl patch pvc iceberg-minio -n analytics -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

### High Availability
For production environments, consider:
- **MinIO Distributed Mode**: Multiple MinIO instances
- **External Storage**: Network-attached storage (NFS, Ceph)
- **Backup Strategy**: Regular data backups
- **Disaster Recovery**: Cross-region replication

## Security Considerations

### Production Hardening
1. **Change Default Credentials**: Update admin username/password
2. **Use Real TLS Certificates**: Replace self-signed certificates
3. **Network Segmentation**: Implement stricter NetworkPolicies
4. **Backup Encryption**: Encrypt backups at rest
5. **Access Logging**: Enable detailed access logs
6. **IAM Integration**: Use IAM roles instead of static credentials

### Secrets Management
```bash
# Update MinIO credentials
kubectl create secret generic iceberg-minio \
  --from-literal=root-user=newadmin \
  --from-literal=root-password=newsecurepassword \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart deployment to pick up new credentials
kubectl rollout restart deployment/iceberg-minio -n analytics
```