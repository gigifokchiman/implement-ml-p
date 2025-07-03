# Terraform Infrastructure Documentation - local

**Generated:** Thu Jul 3 00:14:22 PDT 2025
**Environment:** local
**Terraform Version:** 1.12.1

## Architecture Overview

This document provides an overview of the Terraform infrastructure for the **local** environment.

## Resource Summary

### Providers
```

Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/kubernetes] ~> 2.23
├── provider[registry.terraform.io/hashicorp/helm] ~> 2.11
├── provider[registry.terraform.io/hashicorp/random] ~> 3.4
├── provider[kind.local/gigifokchiman/kind] 0.1.0
├── provider[registry.terraform.io/hashicorp/aws]
└── module.ml_platform
    ├── module.backup
    │   ├── module.aws_backup
    │   │   └── provider[registry.terraform.io/hashicorp/aws]
    │   └── module.kubernetes_backup
    │       ├── provider[registry.terraform.io/hashicorp/kubernetes]
    │       └── provider[registry.terraform.io/hashicorp/helm]
    ├── module.cache
    │   ├── module.aws_cache
    │       └── provider[registry.terraform.io/hashicorp/aws]
    │   └── module.kubernetes_cache
    │       └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.database
    │   ├── module.aws_database
    │       ├── provider[registry.terraform.io/hashicorp/random]
    │       └── provider[registry.terraform.io/hashicorp/aws]
    │   └── module.kubernetes_database
    │       └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.monitoring
    │   └── module.kubernetes_monitoring
    │       ├── provider[registry.terraform.io/hashicorp/kubernetes]
    │       └── provider[registry.terraform.io/hashicorp/helm]
    ├── module.performance_monitoring
    │   ├── module.aws_performance_monitoring
    │       ├── provider[registry.terraform.io/hashicorp/aws]
    │       └── provider[registry.terraform.io/hashicorp/archive]
    │   └── module.kubernetes_performance_monitoring
    │       └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.security
    │   └── module.kubernetes_security
    │       └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.security_scanning
    │   ├── module.aws_security_scanning
    │       ├── provider[registry.terraform.io/hashicorp/aws]
    │       └── provider[registry.terraform.io/hashicorp/archive]
    │   └── module.kubernetes_security_scanning
    │       └── provider[registry.terraform.io/hashicorp/kubernetes]
    └── module.storage
        ├── module.aws_storage
            └── provider[registry.terraform.io/hashicorp/aws]
        └── module.kubernetes_storage
            ├── provider[registry.terraform.io/hashicorp/kubernetes]
            └── provider[registry.terraform.io/hashicorp/random]

Providers required by state:

    provider[kind.local/gigifokchiman/kind]

    provider[registry.terraform.io/hashicorp/kubernetes]

    provider[registry.terraform.io/hashicorp/random]
```

### Outputs
```
cluster_info = <sensitive>
development_urls = {
  "grafana" = "http://localhost:3000"
  "minio" = "http://localhost:9001"
  "prometheus" = "http://localhost:9090"
}
service_connections = <sensitive>
useful_commands = {
  "kubectl_context" = "kubectl config use-context kind-ml-platform-local"
  "minio_credentials" = "Access Key: admin, Secret: stored in secret 'minio-secret' in 'storage' namespace"
  "port_forward_db" = "kubectl port-forward -n database svc/postgres 5432:5432"
  "port_forward_grafana" = "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
  "port_forward_minio" = "kubectl port-forward -n storage svc/minio 9001:9000"
  "port_forward_prometheus" = "kubectl port-forward -n monitoring svc/prometheus-server 9090:9090"
  "port_forward_redis" = "kubectl port-forward -n cache svc/redis 6379:6379"
}
```

## Resource Dependencies

The infrastructure dependencies are visualized in the accompanying diagram files:

- **Basic Graph:** terraform-local-graph.png
- **Interactive Rover:** terraform-local-rover.html

## Security Considerations

### Network Security
- VPC with private subnets for sensitive resources
- Security groups with principle of least privilege
- NAT gateways for outbound internet access

### Data Security
- Encryption at rest for all storage
- Encryption in transit using TLS
- Backup strategies for critical data

### Access Control
- IAM roles with minimal required permissions
- Regular rotation of access keys
- Multi-factor authentication required

## Monitoring and Observability

- CloudWatch for AWS resources
- Prometheus for Kubernetes metrics
- Grafana for visualization
- Jaeger for distributed tracing

---

**Note:** This documentation is auto-generated. For the latest information, refer to the Terraform configuration files.
