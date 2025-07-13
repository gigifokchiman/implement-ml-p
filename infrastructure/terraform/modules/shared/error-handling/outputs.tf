output "error_handling_status" {
  description = "Current error handling status and configuration"
  value = {
    service_name          = var.service_name
    service_healthy       = local.service_healthy
    circuit_breaker_open  = local.circuit_breaker_open
    fallback_strategy     = local.fallback_strategy
    recovery_actions      = local.recovery_actions
    health_checks_enabled = var.health_checks.enabled
  }
}

output "health_monitoring_enabled" {
  description = "Whether health monitoring is enabled"
  value       = var.health_checks.enabled
}

output "circuit_breaker_state" {
  description = "Current circuit breaker state"
  value = {
    enabled  = var.circuit_breaker_config.enabled
    open     = local.circuit_breaker_open
    strategy = var.fallback_config.strategy
  }
}

output "recovery_configuration" {
  description = "Recovery configuration summary"
  value = {
    auto_recovery_enabled = var.auto_recovery.enabled
    retry_max_attempts    = var.retry_policy.max_retries
    error_thresholds      = var.error_thresholds
  }
}
