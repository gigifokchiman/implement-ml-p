# AWS Secrets Manager Provider
# Wraps terraform-aws-modules/secrets-manager with our platform interface


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

# Secrets Manager using terraform-aws-modules/secrets-manager
# Create one secret per configuration
module "secrets_manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  for_each = var.secrets

  # Secret configuration
  name_prefix             = "${local.name_prefix}-${each.key}"
  description             = each.value.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = each.value.recovery_window_in_days
  secret_string           = each.value.secret_string
  secret_binary           = each.value.secret_binary
  ignore_secret_changes   = each.value.ignore_secret_changes

  # Automatic rotation configuration
  enable_rotation = each.value.enable_rotation
  rotation_rules = each.value.enable_rotation ? {
    automatically_after_days = each.value.rotation_days
  } : null

  # Replica configuration for cross-region replication
  replica = each.value.enable_replica && each.value.replica_region != null ? {
    region     = each.value.replica_region
    kms_key_id = each.value.replica_kms_key_id
  } : {}

  # Resource policy for the secret
  create_policy = each.value.resource_policy != null ? true : false
  policy_statements = each.value.resource_policy != null ? {
    custom = jsondecode(each.value.resource_policy)
  } : {}

  tags = local.common_tags
}

# Lambda function for rotation (if needed)
resource "aws_lambda_function" "rotation" {
  count = var.enable_rotation_lambda ? 1 : 0

  filename      = var.rotation_lambda_zip_path
  function_name = "${local.name_prefix}-rotation"
  role          = aws_iam_role.rotation_lambda[0].arn
  handler       = var.rotation_lambda_handler
  runtime       = var.rotation_lambda_runtime
  timeout       = var.rotation_lambda_timeout

  environment {
    variables = var.rotation_lambda_env_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.rotation_lambda,
    aws_cloudwatch_log_group.rotation_lambda,
  ]

  tags = local.common_tags
}

# IAM role for rotation Lambda
resource "aws_iam_role" "rotation_lambda" {
  count = var.enable_rotation_lambda ? 1 : 0

  name = "${local.name_prefix}-rotation-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy attachment for rotation Lambda
resource "aws_iam_role_policy_attachment" "rotation_lambda" {
  count = var.enable_rotation_lambda ? 1 : 0

  role       = aws_iam_role.rotation_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for secrets access
resource "aws_iam_role_policy" "rotation_lambda_secrets" {
  count = var.enable_rotation_lambda ? 1 : 0

  name = "${local.name_prefix}-rotation-lambda-secrets"
  role = aws_iam_role.rotation_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [for secret_module in module.secrets_manager : secret_module.secret_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : []
      }
    ]
  })
}

# CloudWatch Log Group for rotation Lambda
resource "aws_cloudwatch_log_group" "rotation_lambda" {
  count = var.enable_rotation_lambda ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-rotation"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}
