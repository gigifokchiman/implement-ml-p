# AWS KMS Provider
# Wraps terraform-aws-modules/kms with our platform interface

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.name}-${var.environment}"

  common_tags = merge(var.tags, {
    "Name"        = local.name_prefix
    "environment" = var.environment
    "managed-by"  = "terraform"
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key using terraform-aws-modules/kms
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description = var.description
  key_usage   = var.key_usage
  customer_master_key_spec = var.key_spec

  # Key policy
  key_administrators = var.key_administrators
  key_users          = var.key_users
  key_service_users  = var.key_service_users

  # Allow root access and cluster-specific permissions
  key_statements = length(var.service_principals) > 0 ? concat([
    {
      sid    = "Enable IAM User Permissions"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
      ]
      actions   = ["kms:*"]
      resources = ["*"]
    },
    {
      sid    = "Allow use of the key for encryption/decryption"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = var.service_principals
        }
      ]
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  ], var.additional_key_statements) : concat([
    {
      sid    = "Enable IAM User Permissions"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
      ]
      actions   = ["kms:*"]
      resources = ["*"]
    }
  ], var.additional_key_statements)

  # Deletion settings
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  # Alias
  aliases = var.aliases

  tags = local.common_tags
}