# Platform-agnostic security scanning interface
# Supports container image scanning and vulnerability assessment

locals {
  is_local = var.environment == "local"
}

module "kubernetes_security_scanning" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/security-scanning"

  name        = var.name
  environment = var.environment
  config      = var.config
  namespaces  = var.namespaces
  tags        = var.tags
}

module "aws_security_scanning" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/security-scanning"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags
}