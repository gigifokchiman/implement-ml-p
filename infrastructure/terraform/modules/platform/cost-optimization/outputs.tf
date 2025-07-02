output "cost_monitoring" {
  description = "Cost monitoring configuration and endpoints"
  value = var.environment == "local" ? (
    length(module.kubernetes_cost_optimization) > 0 ? module.kubernetes_cost_optimization[0].cost_monitoring : {}
    ) : (
    length(module.aws_cost_optimization) > 0 ? module.aws_cost_optimization[0].cost_monitoring : {}
  )
}

output "resource_scheduling" {
  description = "Resource scheduling configuration"
  value = var.environment == "local" ? (
    length(module.kubernetes_cost_optimization) > 0 ? module.kubernetes_cost_optimization[0].resource_scheduling : {}
    ) : (
    length(module.aws_cost_optimization) > 0 ? module.aws_cost_optimization[0].resource_scheduling : {}
  )
}

output "optimization_reports" {
  description = "Cost optimization reports and recommendations"
  value = var.environment == "local" ? (
    length(module.kubernetes_cost_optimization) > 0 ? module.kubernetes_cost_optimization[0].optimization_reports : {}
    ) : (
    length(module.aws_cost_optimization) > 0 ? module.aws_cost_optimization[0].optimization_reports : {}
  )
}

output "savings_potential" {
  description = "Estimated cost savings from optimization"
  value = var.environment == "local" ? (
    length(module.kubernetes_cost_optimization) > 0 ? module.kubernetes_cost_optimization[0].savings_potential : {}
    ) : (
    length(module.aws_cost_optimization) > 0 ? module.aws_cost_optimization[0].savings_potential : {}
  )
}