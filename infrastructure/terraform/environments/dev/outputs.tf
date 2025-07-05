# Development Environment Outputs

# Cluster Information
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.data_platform.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
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

# AWS-specific Information
output "aws_cluster_info" {
  description = "AWS-specific cluster information"
  value       = module.data_platform.aws_cluster_info
  sensitive   = true
}

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
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.data_platform.cluster_name}"
}

# Useful Commands
output "useful_commands" {
  description = "Useful commands for this environment"
  value = {
    kubectl_config     = "aws eks update-kubeconfig --region ${var.region} --name ${module.data_platform.cluster_name}"
    get_nodes         = "kubectl get nodes -o wide"
    get_node_groups   = "kubectl get nodes --show-labels"
    port_forward_db   = "kubectl port-forward -n database svc/postgres 5432:5432"
  }
}

# Resource Summary
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    cluster = {
      name     = module.data_platform.cluster_name
      endpoint = module.data_platform.cluster_endpoint
      provider = module.data_platform.cluster_provider
    }
    services = {
      database_enabled = module.data_platform.database != null
      cache_enabled    = module.data_platform.cache != null
      storage_enabled  = module.data_platform.storage != null
      monitoring_enabled = module.data_platform.monitoring != null
    }
  }
}