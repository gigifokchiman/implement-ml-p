# Cross-Cutting Concerns Outputs

output "standard_tags" {
  description = "Standardized tags for all resources"
  value       = local.standard_tags
}

output "logging_config" {
  description = "Standardized logging configuration"
  value       = local.logging_config
}

output "monitoring_config" {
  description = "Standardized monitoring configuration"
  value       = local.monitoring_config
}

output "security_config" {
  description = "Standardized security configuration"
  value       = local.security_config
}

output "service_labels" {
  description = "Standard service discovery labels"
  value = {
    "app.kubernetes.io/name"       = var.service_name
    "app.kubernetes.io/instance"   = var.instance_name
    "app.kubernetes.io/version"    = var.service_version
    "app.kubernetes.io/component"  = var.component_type
    "app.kubernetes.io/part-of"    = var.platform_name
    "app.kubernetes.io/managed-by" = "terraform"
    "platform.io/service-type"    = var.service_type
    "platform.io/service-tier"    = var.service_tier
    "platform.io/security-level"  = var.security_level
  }
}

output "namespace_labels" {
  description = "Standard namespace labels"
  value = merge(local.standard_tags, {
    "name"                         = var.namespace
    "platform.io/service-type"    = var.service_type
    "platform.io/service-tier"    = var.service_tier
    "platform.io/monitoring"      = tostring(local.monitoring_config.enabled)
    "platform.io/logging"         = tostring(local.logging_config.enabled)
    "platform.io/security-level"  = var.security_level
  })
}