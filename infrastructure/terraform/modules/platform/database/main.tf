# Platform-agnostic database interface
# Delegates to provider-specific implementations


locals {
  is_local = var.config.instance_class == "local"
}

# Kubernetes implementation for local environments
module "kubernetes_database" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/database"

  name        = var.name
  namespace   = var.namespace
  environment = var.environment
  config      = var.config
  tags        = var.tags
}

# AWS implementation for cloud environments
module "aws_database" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/database"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags

  # Provider-specific configuration
  vpc_id                = var.provider_config.vpc_id
  subnet_ids            = var.provider_config.subnet_ids
  allowed_cidr_blocks   = var.provider_config.allowed_cidr_blocks
  backup_retention_days = var.provider_config.backup_retention_days
  deletion_protection   = var.provider_config.deletion_protection
}
