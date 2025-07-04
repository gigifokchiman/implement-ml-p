# Platform-agnostic cache interface
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
  is_local = var.config.node_type == "local"
}

# Kubernetes implementation for local environments
module "kubernetes_cache" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/cache"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags
}

# AWS implementation for cloud environments
module "aws_cache" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/cache"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags

  # AWS-specific variables
  vpc_id              = var.vpc_id
  subnet_ids          = var.subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks
}