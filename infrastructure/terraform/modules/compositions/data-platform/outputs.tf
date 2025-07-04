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

output "database" {
  description = "Database connection details"
  value       = module.database.connection
  sensitive   = true
}

output "database_credentials" {
  description = "Database credentials"
  value       = module.database.credentials
  sensitive   = true
}

output "cache" {
  description = "Cache connection details"
  value       = module.cache.connection
  sensitive   = true
}

output "cache_credentials" {
  description = "Cache credentials"
  value       = module.cache.credentials
  sensitive   = true
}

output "storage" {
  description = "Storage connection details"
  value       = module.storage.connection
  sensitive   = true
}

output "storage_credentials" {
  description = "Storage credentials"
  value       = module.storage.credentials
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
    enabled = false
    message = "Security disabled for local environment"
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
  value = {
    scanner_endpoints      = module.security_scanning.scanner_endpoints
    vulnerability_database = module.security_scanning.vulnerability_database
    scan_reports_location  = module.security_scanning.scan_reports_location
  }
}

output "performance_monitoring" {
  description = "Performance monitoring endpoints and dashboards"
  value = {
    apm_endpoints     = module.performance_monitoring.apm_endpoints
    tracing_endpoints = module.performance_monitoring.tracing_endpoints
    metrics_endpoints = module.performance_monitoring.metrics_endpoints
    dashboards        = module.performance_monitoring.dashboards
  }
}