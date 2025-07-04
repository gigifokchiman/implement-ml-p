# Terraform Infrastructure Documentation - local

**Generated:** Thu Jul 3 16:36:07 PDT 2025
**Environment:** local
**Terraform Version:** 1.12.2

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
├── module.security_bootstrap
│   ├── provider[registry.terraform.io/hashicorp/kubernetes] ~> 2.23
│   ├── provider[registry.terraform.io/hashicorp/helm] ~> 2.11
│   ├── provider[registry.terraform.io/hashicorp/random] ~> 3.5
│   └── provider[registry.terraform.io/hashicorp/time] ~> 0.9
├── module.data_platform
│   ├── provider[registry.terraform.io/hashicorp/aws]
│   ├── provider[registry.terraform.io/hashicorp/kubernetes]
│   ├── provider[registry.terraform.io/hashicorp/helm]
│   ├── module.security_scanning
│       ├── module.aws_security_scanning
│       │   ├── provider[registry.terraform.io/hashicorp/aws]
│       │   └── provider[registry.terraform.io/hashicorp/archive]
│       └── module.kubernetes_security_scanning
│           └── provider[registry.terraform.io/hashicorp/kubernetes]
│   ├── module.storage
│       ├── provider[registry.terraform.io/hashicorp/aws]
│       ├── provider[registry.terraform.io/hashicorp/kubernetes]
│       ├── provider[registry.terraform.io/hashicorp/helm]
│       ├── module.aws_storage
│           └── provider[registry.terraform.io/hashicorp/aws]
│       └── module.kubernetes_storage
│           ├── provider[registry.terraform.io/hashicorp/kubernetes]
│           └── provider[registry.terraform.io/hashicorp/random]
│   ├── module.backup
│       ├── module.kubernetes_backup
│           ├── provider[registry.terraform.io/hashicorp/helm]
│           └── provider[registry.terraform.io/hashicorp/kubernetes]
│       └── module.aws_backup
│           └── provider[registry.terraform.io/hashicorp/aws]
│   ├── module.cache
│       ├── provider[registry.terraform.io/hashicorp/helm]
│       ├── provider[registry.terraform.io/hashicorp/aws]
│       ├── provider[registry.terraform.io/hashicorp/kubernetes]
│       ├── module.aws_cache
│           └── provider[registry.terraform.io/hashicorp/aws]
│       └── module.kubernetes_cache
│           └── provider[registry.terraform.io/hashicorp/kubernetes]
│   ├── module.database
│       ├── provider[registry.terraform.io/hashicorp/helm]
│       ├── provider[registry.terraform.io/hashicorp/aws]
│       ├── provider[registry.terraform.io/hashicorp/kubernetes]
│       ├── module.aws_database
│           ├── provider[registry.terraform.io/hashicorp/aws]
│           └── provider[registry.terraform.io/hashicorp/random]
│       └── module.kubernetes_database
│           └── provider[registry.terraform.io/hashicorp/kubernetes]
│   ├── module.monitoring
│       └── module.kubernetes_monitoring
│           ├── provider[registry.terraform.io/hashicorp/kubernetes]
│           └── provider[registry.terraform.io/hashicorp/helm]
│   ├── module.performance_monitoring
│       ├── module.aws_performance_monitoring
│           ├── provider[registry.terraform.io/hashicorp/aws]
│           └── provider[registry.terraform.io/hashicorp/archive]
│       └── module.kubernetes_performance_monitoring
│           └── provider[registry.terraform.io/hashicorp/kubernetes]
│   └── module.security
│       └── module.kubernetes_security
│           └── provider[registry.terraform.io/hashicorp/kubernetes]
└── module.ml_platform
    ├── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── provider[registry.terraform.io/hashicorp/helm]
    ├── provider[registry.terraform.io/hashicorp/aws]
    ├── module.storage
        ├── provider[registry.terraform.io/hashicorp/aws]
        ├── provider[registry.terraform.io/hashicorp/kubernetes]
        ├── provider[registry.terraform.io/hashicorp/helm]
        ├── module.aws_storage
            └── provider[registry.terraform.io/hashicorp/aws]
        └── module.kubernetes_storage
            ├── provider[registry.terraform.io/hashicorp/kubernetes]
            └── provider[registry.terraform.io/hashicorp/random]
    ├── module.backup
        ├── module.aws_backup
            └── provider[registry.terraform.io/hashicorp/aws]
        └── module.kubernetes_backup
            ├── provider[registry.terraform.io/hashicorp/helm]
            └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.cache
        ├── provider[registry.terraform.io/hashicorp/kubernetes]
        ├── provider[registry.terraform.io/hashicorp/helm]
        ├── provider[registry.terraform.io/hashicorp/aws]
        ├── module.aws_cache
            └── provider[registry.terraform.io/hashicorp/aws]
        └── module.kubernetes_cache
            └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.database
        ├── provider[registry.terraform.io/hashicorp/kubernetes]
        ├── provider[registry.terraform.io/hashicorp/helm]
        ├── provider[registry.terraform.io/hashicorp/aws]
        ├── module.aws_database
            ├── provider[registry.terraform.io/hashicorp/aws]
            └── provider[registry.terraform.io/hashicorp/random]
        └── module.kubernetes_database
            └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.monitoring
        └── module.kubernetes_monitoring
            ├── provider[registry.terraform.io/hashicorp/helm]
            └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.performance_monitoring
        ├── module.aws_performance_monitoring
            ├── provider[registry.terraform.io/hashicorp/aws]
            └── provider[registry.terraform.io/hashicorp/archive]
        └── module.kubernetes_performance_monitoring
            └── provider[registry.terraform.io/hashicorp/kubernetes]
    ├── module.security
        └── module.kubernetes_security
            └── provider[registry.terraform.io/hashicorp/kubernetes]
    └── module.security_scanning
        ├── module.aws_security_scanning
            ├── provider[registry.terraform.io/hashicorp/archive]
            └── provider[registry.terraform.io/hashicorp/aws]
        └── module.kubernetes_security_scanning
            └── provider[registry.terraform.io/hashicorp/kubernetes]

Providers required by state:

    provider[registry.terraform.io/hashicorp/kubernetes]

    provider[registry.terraform.io/hashicorp/random]

    provider[registry.terraform.io/hashicorp/time]

    provider[kind.local/gigifokchiman/kind]

    provider[registry.terraform.io/hashicorp/helm]
```

### Outputs

```
data_platform_cluster_info = <sensitive>
data_platform_service_connections = <sensitive>
development_urls = {
  "grafana" = "http://localhost:3000"
  "minio" = "http://localhost:9001"
  "prometheus" = "http://localhost:9090"
}
ml_platform_cluster_info = <sensitive>
ml_platform_service_connections = <sensitive>
useful_commands = {
  "kubectl_context_data" = "kubectl config use-context kind-data-platform-local"
  "kubectl_context_ml" = "kubectl config use-context kind-ml-platform-local"
  "list_clusters" = "kind get clusters"
  "minio_credentials" = "Access Key: admin, Secret: stored in secret 'minio-secret' in 'storage' namespace"
  "port_forward_data_db" = "kubectl --context kind-data-platform-local port-forward -n database svc/postgres 5433:5432"
  "port_forward_data_grafana" = "kubectl --context kind-data-platform-local port-forward -n monitoring svc/prometheus-grafana 3001:80"
  "port_forward_data_minio" = "kubectl --context kind-data-platform-local port-forward -n storage svc/minio 9002:9000"
  "port_forward_data_prometheus" = "kubectl --context kind-data-platform-local port-forward -n monitoring svc/prometheus-server 9091:9090"
  "port_forward_data_redis" = "kubectl --context kind-data-platform-local port-forward -n cache svc/redis 6380:6379"
  "port_forward_ml_db" = "kubectl --context kind-ml-platform-local port-forward -n database svc/postgres 5432:5432"
  "port_forward_ml_grafana" = "kubectl --context kind-ml-platform-local port-forward -n monitoring svc/prometheus-grafana 3000:80"
  "port_forward_ml_minio" = "kubectl --context kind-ml-platform-local port-forward -n storage svc/minio 9001:9000"
  "port_forward_ml_prometheus" = "kubectl --context kind-ml-platform-local port-forward -n monitoring svc/prometheus-server 9090:9090"
  "port_forward_ml_redis" = "kubectl --context kind-ml-platform-local port-forward -n cache svc/redis 6379:6379"
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
