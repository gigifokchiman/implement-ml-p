# Local Environment Outputs

# Cluster Information
output "cluster_name" {
  description = "Kind cluster name"
  value       = module.data_platform.cluster_name
}

output "cluster_endpoint" {
  description = "Kind cluster endpoint"
  value       = module.data_platform.cluster_endpoint
}

output "cluster_provider" {
  description = "Cluster provider type"
  value       = module.data_platform.cluster_provider
}

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = module.data_platform.kubeconfig
  sensitive   = true
}

# Kind-specific Information
# output "kind_cluster_info" {
#   description = "Kind-specific cluster information"
#   value       = module.data_platform.kind_cluster_info
#   sensitive   = true
# }

# Platform Services
output "database" {
  description = "Database connection details"
  value       = module.data_platform.database
  sensitive   = true
}

output "cache" {
  description = "Cache connection details"
  value       = module.data_platform.cache
  sensitive   = true
}

output "storage" {
  description = "Storage connection details"
  value       = module.data_platform.storage
  sensitive   = true
}

output "monitoring" {
  description = "Monitoring endpoints"
  value       = module.data_platform.monitoring
  sensitive   = true
}

# Connection Information
output "kubectl_config_command" {
  description = "kubectl config command"
  value       = "kubectl config use-context kind-${module.data_platform.cluster_name}"
}

# Useful Commands
output "useful_commands" {
  description = "Useful commands for this environment"
  value = {
    kubectl_config       = "kubectl config use-context kind-${module.data_platform.cluster_name}"
    get_nodes           = "kubectl get nodes -o wide"
    get_pods            = "kubectl get pods --all-namespaces"
    port_forward_grafana = "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    port_forward_minio   = "kubectl port-forward -n storage svc/minio 9001:9000"
    registry_catalog     = "curl http://localhost:5001/v2/_catalog"
    push_image_example   = "docker tag myimage:latest localhost:5001/myimage:latest && docker push localhost:5001/myimage:latest"
  }
}

# Resource Summary
output "resource_summary" {
  description = "Summary of created resources"
  sensitive   = true
  value = {
    cluster = {
      name     = module.data_platform.cluster_name
      endpoint = module.data_platform.cluster_endpoint
      provider = module.data_platform.cluster_provider
    }
    services = {
      database_enabled   = module.data_platform.database != null
      cache_enabled      = module.data_platform.cache != null
      storage_enabled    = module.data_platform.storage != null
      monitoring_enabled = module.data_platform.monitoring != null
    }
    local_access = {
      registry_url = try(module.data_platform.kind_cluster_info.local_registry_url, "localhost:5001")
      frontend_url = try(module.data_platform.kind_cluster_info.port_mappings.http, "http://localhost:8080")
    }
  }
}

# Development URLs
output "development_urls" {
  description = "Local development URLs"
  sensitive   = true
  value = {
    frontend     = try(module.data_platform.kind_cluster_info.port_mappings.http, "http://localhost:8080")
    registry     = try(module.data_platform.kind_cluster_info.local_registry_url, "localhost:5001")
    grafana      = "http://localhost:3000"  # Port forward required
    prometheus   = "http://localhost:9090" # Port forward required
    minio        = "http://localhost:9001" # Port forward required
  }
}
