# Platform-agnostic database interface
# Delegates to provider-specific implementations

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  is_local = var.config.instance_class == "local"
}

# Kubernetes implementation for local environments
module "kubernetes_database" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/database"

  name        = var.name
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

  # AWS-specific variables (will be passed from composition)
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  backup_retention_days = var.backup_retention_days
  deletion_protection   = var.deletion_protection
}