# Local Environment Outputs

output "cluster_name" {
  description = "Name of the Kind cluster"
  value       = kind_cluster.data_platform.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = kind_cluster.data_platform.endpoint
}

# Secure secret retrieval (no plaintext in outputs)
output "secret_store_namespace" {
  description = "Namespace where secrets are stored"
  value       = module.secret_store.secret_store_namespace
}

output "secret_retrieval_commands" {
  description = "Commands to securely retrieve secrets (no plaintext exposure)"
  value       = module.secret_store.secret_retrieval_commands
}

# Service Access Instructions
output "service_access" {
  description = "Instructions for accessing services"
  value = {
    argocd = {
      command  = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
      url      = "https://localhost:8080"
      username = "admin"
      password = "Run: terraform output -raw argocd_admin_password"
    }
    grafana = {
      command  = "kubectl port-forward svc/prometheus-grafana -n data-platform-monitoring 3000:80"
      url      = "http://localhost:3000"
      username = "admin"
      password = "Run: terraform output -raw grafana_admin_password"
    }
    postgres = {
      command = "kubectl port-forward -n data-platform-database svc/postgres 5432:5432"
      url     = "postgresql://admin:password@localhost:5432/metadata"
    }
    redis = {
      command = "kubectl port-forward -n data-platform-cache svc/redis 6379:6379"
      url     = "redis://localhost:6379"
    }
    minio = {
      command  = "kubectl port-forward -n data-platform-storage svc/minio 9001:9000"
      url      = "http://localhost:9001"
      username = "minioadmin"
      password = "minioadmin"
    }
  }
}