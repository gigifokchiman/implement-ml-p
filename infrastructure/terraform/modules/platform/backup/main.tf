# Platform-agnostic backup interface

locals {
  is_local = var.environment == "local"
}

# Kubernetes implementation for local environments
module "kubernetes_backup" {
  count  = local.is_local ? 1 : 0
  source = "../../providers/kubernetes/backup"

  name        = var.name
  environment = var.environment

  # Extract relevant config for Kubernetes
  config = {
    backup_schedule     = var.config.backup_schedule
    retention_days      = var.config.retention_days
    enable_cross_region = var.config.enable_cross_region
    enable_encryption   = var.config.enable_encryption
  }

  tags = var.tags
}

# AWS implementation for cloud environments  
module "aws_backup" {
  count  = !local.is_local ? 1 : 0
  source = "../../providers/aws/backup"

  name        = var.name
  environment = var.environment
  tags        = var.tags

  # AWS-specific backup configuration
  kms_key_arn        = var.config.kms_key_arn
  backup_rule_name   = var.config.backup_rule_name
  backup_schedule    = var.config.backup_schedule
  cold_storage_after = var.config.cold_storage_after
  delete_after       = var.config.delete_after
  backup_rds_enabled = var.config.backup_rds_enabled
  backup_ebs_enabled = var.config.backup_ebs_enabled
}