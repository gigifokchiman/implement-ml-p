# Platform-agnostic performance monitoring interface
# Supports APM, distributed tracing, and advanced metrics collection

locals {
  is_local = var.environment == "local"
}

module "kubernetes_performance_monitoring" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/performance-monitoring"

  name        = var.name
  environment = var.environment
  config      = var.config
  namespaces  = var.namespaces
  tags        = var.tags
}

module "aws_performance_monitoring" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/performance-monitoring"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags
}
