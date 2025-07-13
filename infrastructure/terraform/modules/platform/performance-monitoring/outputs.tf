output "apm_endpoints" {
  description = "APM service endpoints"
  value = var.environment == "local" ? (
    length(module.kubernetes_performance_monitoring) > 0 ? module.kubernetes_performance_monitoring[0].apm_endpoints : {}
    ) : (
    length(module.aws_performance_monitoring) > 0 ? module.aws_performance_monitoring[0].apm_endpoints : {}
  )
}

output "tracing_endpoints" {
  description = "Distributed tracing endpoints"
  value = var.environment == "local" ? (
    length(module.kubernetes_performance_monitoring) > 0 ? module.kubernetes_performance_monitoring[0].tracing_endpoints : {}
    ) : (
    length(module.aws_performance_monitoring) > 0 ? module.aws_performance_monitoring[0].tracing_endpoints : {}
  )
}

output "metrics_endpoints" {
  description = "Custom metrics endpoints"
  value = var.environment == "local" ? (
    length(module.kubernetes_performance_monitoring) > 0 ? module.kubernetes_performance_monitoring[0].metrics_endpoints : {}
    ) : (
    length(module.aws_performance_monitoring) > 0 ? module.aws_performance_monitoring[0].metrics_endpoints : {}
  )
}

output "dashboards" {
  description = "Available performance monitoring dashboards"
  value = var.environment == "local" ? (
    length(module.kubernetes_performance_monitoring) > 0 ? module.kubernetes_performance_monitoring[0].dashboards : []
    ) : (
    length(module.aws_performance_monitoring) > 0 ? module.aws_performance_monitoring[0].dashboards : []
  )
}
