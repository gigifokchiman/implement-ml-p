# Cluster Infrastructure
output "cluster" {
  description = "Cluster information"
  value       = module.cluster.cluster_info
  sensitive   = true
}

output "cluster_name" {
  description = "Cluster name"
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Cluster endpoint"
  value       = module.cluster.cluster_endpoint
}

output "cluster_provider" {
  description = "Cluster provider type (aws or kind)"
  value       = module.cluster.provider_type
}

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = module.cluster.kubeconfig
  sensitive   = true
}

# AWS-specific outputs (when using AWS)
output "aws_cluster_info" {
  description = "AWS-specific cluster information"
  value       = module.cluster.aws_cluster_outputs
  sensitive   = true
}

# Kind-specific outputs (when using Kind)
output "kind_cluster_info" {
  description = "Kind-specific cluster information"
  value       = module.cluster.kind_cluster_outputs
  sensitive   = true
}

output "team_databases" {
  description = "Database connection details per team"
  value       = { for k, v in module.team_databases : k => v.connection }
  sensitive   = true
}

output "team_database_credentials" {
  description = "Database credentials per team"
  value       = { for k, v in module.team_databases : k => v.credentials }
  sensitive   = true
}

output "team_storage" {
  description = "Storage connection details per team"
  value       = { for k, v in module.team_storage : k => v.connection }
  sensitive   = true
}

output "team_storage_credentials" {
  description = "Storage credentials per team"
  value       = { for k, v in module.team_storage : k => v.credentials }
  sensitive   = true
}

output "monitoring" {
  description = "Monitoring endpoints"
  value = length(module.monitoring) > 0 ? module.monitoring[0].endpoints : {
    enabled = false
    message = "Monitoring disabled for local environment"
  }
  sensitive = true
}

output "monitoring_dashboards" {
  description = "Available monitoring dashboards"
  value = length(module.monitoring) > 0 ? module.monitoring[0].dashboards : {
    enabled = false
    message = "Monitoring disabled for local environment"
  }
}

output "security" {
  description = "Security policies status"
  value = length(module.security) > 0 ? module.security[0].security_policies : {
    pod_security_enabled     = false
    pod_security_standard    = "baseline"
    network_policies_enabled = false
    secured_namespaces       = []
  }
}

output "backup" {
  description = "Backup configuration"
  value = length(module.backup) > 0 ? {
    schedule       = module.backup[0].backup_schedule
    retention_days = module.backup[0].retention_days
    } : {
    schedule       = "disabled"
    retention_days = 0
  }
  sensitive = true
}

output "security_scanning" {
  description = "Security scanning endpoints and configuration"
  value = length(module.security_scanning) > 0 ? {
    scanning_facilities = module.security_scanning[0].scanning_facilities
    namespace           = module.security_scanning[0].namespace
    argocd_project      = module.security_scanning[0].argocd_project
    enabled             = true
    message             = "Security scanning enabled"
    } : {
    scanning_facilities = {}
    namespace           = ""
    argocd_project      = null
    enabled             = false
    message             = "Security scanning disabled"
  }
}

output "performance_monitoring" {
  description = "Performance monitoring endpoints and dashboards"
  value = length(module.performance_monitoring) > 0 ? {
    apm_endpoints     = module.performance_monitoring[0].apm_endpoints
    tracing_endpoints = module.performance_monitoring[0].tracing_endpoints
    metrics_endpoints = module.performance_monitoring[0].metrics_endpoints
    dashboards        = module.performance_monitoring[0].dashboards
    enabled           = true
    message           = "Performance monitoring enabled"
    } : {
    apm_endpoints     = {}
    tracing_endpoints = {}
    metrics_endpoints = {}
    dashboards        = []
    enabled           = false
    message           = "Performance monitoring disabled"
  }
}