# Platform-agnostic cost optimization interface
# Supports resource scheduling, cost monitoring, and optimization recommendations

locals {
  is_local = var.environment == "local"
}

module "kubernetes_cost_optimization" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/cost-optimization"

  name        = var.name
  environment = var.environment
  config      = var.config
  namespaces  = var.namespaces
  tags        = var.tags
}

module "aws_cost_optimization" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/cost-optimization"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags
}