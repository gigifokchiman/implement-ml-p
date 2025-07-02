output "cost_monitoring" {
  description = "Cost monitoring configuration and endpoints"
  value = {
    kubecost_endpoint = var.config.enable_cost_monitoring ? "http://${kubernetes_service.kubecost[0].metadata[0].name}.${kubernetes_service.kubecost[0].metadata[0].namespace}.svc.cluster.local:9003" : null
    kubecost_metrics  = var.config.enable_cost_monitoring ? "http://${kubernetes_service.kubecost[0].metadata[0].name}.${kubernetes_service.kubecost[0].metadata[0].namespace}.svc.cluster.local:9090/metrics" : null
    namespace         = kubernetes_namespace.cost_optimization.metadata[0].name
  }
}

output "resource_scheduling" {
  description = "Resource scheduling configuration"
  value = {
    enabled           = var.config.enable_resource_scheduling
    downtime_schedule = var.config.schedule_downtime
    uptime_schedule   = var.config.schedule_uptime
    scaler_job        = var.config.enable_resource_scheduling && var.environment != "prod" ? kubernetes_cron_job_v1.resource_scaler[0].metadata[0].name : null
  }
}

output "optimization_reports" {
  description = "Cost optimization reports and recommendations"
  value = {
    resource_quotas_applied = length(kubernetes_resource_quota.namespace_quotas)
    limit_ranges_applied    = length(kubernetes_limit_range.namespace_limits)
    hpa_configurations      = var.config.enable_auto_scaling ? length(kubernetes_horizontal_pod_autoscaler_v2.cost_aware_hpa) : 0
    kubecost_dashboard      = var.config.enable_cost_monitoring ? "http://localhost:9003" : null
  }
}

output "savings_potential" {
  description = "Estimated cost savings from optimization"
  value = {
    resource_quotas_savings   = "30-50% through resource limits"
    scheduling_savings        = var.config.enable_resource_scheduling && var.environment != "prod" ? "40-60% in non-production environments" : null
    auto_scaling_savings      = var.config.enable_auto_scaling ? "20-40% through dynamic scaling" : null
    estimated_monthly_savings = var.environment != "prod" ? "${var.config.cost_budget_limit * 0.4} USD" : "${var.config.cost_budget_limit * 0.2} USD"
  }
}

output "namespace" {
  description = "Cost optimization namespace"
  value       = kubernetes_namespace.cost_optimization.metadata[0].name
}

output "useful_commands" {
  description = "Useful commands for cost optimization operations"
  value = [
    "# Port forward to Kubecost dashboard",
    var.config.enable_cost_monitoring ? "kubectl port-forward -n ${kubernetes_namespace.cost_optimization.metadata[0].name} svc/kubecost 9003:9003" : null,
    "# Check resource quotas",
    "kubectl get resourcequota --all-namespaces",
    "# Check limit ranges",
    "kubectl get limitrange --all-namespaces",
    "# Check HPA status",
    var.config.enable_auto_scaling ? "kubectl get hpa --all-namespaces" : null,
    "# Check resource scaler job status",
    var.config.enable_resource_scheduling && var.environment != "prod" ? "kubectl get cronjob -n ${kubernetes_namespace.cost_optimization.metadata[0].name} resource-scaler" : null,
    "# View cost optimization namespace",
    "kubectl get all -n ${kubernetes_namespace.cost_optimization.metadata[0].name}",
    "# Manual scale down (for testing)",
    "kubectl scale deployment --replicas=0 -n database postgres",
    "# Manual scale up (for testing)",
    "kubectl scale deployment --replicas=1 -n database postgres"
  ]
}