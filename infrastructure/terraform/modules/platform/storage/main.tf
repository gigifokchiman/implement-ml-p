# Platform-agnostic storage interface
# Delegates to provider-specific implementations


locals {
  is_local = var.environment == "local"
}

# Kubernetes implementation for local environments
module "kubernetes_storage" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/storage"

  name        = var.name
  namespace   = var.namespace
  environment = var.environment
  config      = var.config
  tags        = var.tags
}

# AWS implementation for cloud environments
module "aws_storage" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/storage"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags

  # Provider-specific configuration
  region = var.provider_config.region
}
