# Cross-Cutting Concerns Module
# Handles shared concerns across all modules (logging, monitoring, tagging, etc.)


# Cross-cutting configuration
locals {
  # Standardized tagging strategy
  standard_tags = merge(var.base_tags, {
    "managed-by"        = "terraform"
    "platform"          = var.platform_name
    "environment"       = var.environment
    "cost-center"       = "platform-engineering"
    "terraform-module"  = var.module_name
    "terraform-version" = "1.5"
  })

  # Logging configuration
  logging_config = {
    enabled        = var.logging_config.enabled
    level          = var.logging_config.level
    destinations   = var.logging_config.destinations
    retention_days = var.logging_config.retention_days
  }

  # Monitoring configuration  
  monitoring_config = {
    enabled            = var.monitoring_config.enabled
    metrics_enabled    = var.monitoring_config.metrics_enabled
    alerts_enabled     = var.monitoring_config.alerts_enabled
    dashboards_enabled = var.monitoring_config.dashboards_enabled
  }

  # Security configuration
  security_config = {
    pod_security_enabled     = var.security_config.pod_security_enabled
    network_policies_enabled = var.security_config.network_policies_enabled
    rbac_enabled             = var.security_config.rbac_enabled
  }
}

# Service Discovery Labels
resource "kubernetes_labels" "service_discovery" {
  count = var.enable_service_discovery ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = var.namespace
  }

  labels = merge(local.standard_tags, {
    "app.kubernetes.io/name"       = var.service_name
    "app.kubernetes.io/instance"   = var.instance_name
    "app.kubernetes.io/version"    = var.service_version
    "app.kubernetes.io/component"  = var.component_type
    "app.kubernetes.io/part-of"    = var.platform_name
    "app.kubernetes.io/managed-by" = "terraform"

    # Service discovery labels
    "platform.io/service-type"   = var.service_type
    "platform.io/service-tier"   = var.service_tier
    "platform.io/monitoring"     = tostring(local.monitoring_config.enabled)
    "platform.io/logging"        = tostring(local.logging_config.enabled)
    "platform.io/security-level" = var.security_level
  })
}

# ServiceMonitor creation removed - handled by ArgoCD GitOps

# Application NetworkPolicies removed - handled by ArgoCD GitOps
# Infrastructure-level network policies (deny-all defaults) should be managed separately
