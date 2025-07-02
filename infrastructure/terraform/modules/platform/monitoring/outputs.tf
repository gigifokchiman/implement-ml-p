output "endpoints" {
  description = "Monitoring endpoints"
  value       = module.kubernetes_monitoring.endpoints
  sensitive   = true
}

output "dashboards" {
  description = "Available dashboards"
  value       = module.kubernetes_monitoring.dashboards
}