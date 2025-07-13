# AWS Audit Logging Provider
# Enables EKS audit logging to CloudWatch


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

# CloudWatch Log Group for EKS audit logs
resource "aws_cloudwatch_log_group" "eks_audit" {
  name              = "/aws/eks/${var.cluster_name}/audit"
  retention_in_days = var.config.retention_days
  kms_key_id        = var.kms_key_id

  tags = local.common_tags
}

# CloudWatch Log Group for API server logs
resource "aws_cloudwatch_log_group" "eks_api" {
  name              = "/aws/eks/${var.cluster_name}/api"
  retention_in_days = var.config.retention_days
  kms_key_id        = var.kms_key_id

  tags = local.common_tags
}

# CloudWatch Log Group for authenticator logs
resource "aws_cloudwatch_log_group" "eks_authenticator" {
  name              = "/aws/eks/${var.cluster_name}/authenticator"
  retention_in_days = var.config.retention_days
  kms_key_id        = var.kms_key_id

  tags = local.common_tags
}

# CloudWatch Log Group for controller manager logs
resource "aws_cloudwatch_log_group" "eks_controller_manager" {
  name              = "/aws/eks/${var.cluster_name}/controllerManager"
  retention_in_days = var.config.retention_days
  kms_key_id        = var.kms_key_id

  tags = local.common_tags
}

# CloudWatch Log Group for scheduler logs
resource "aws_cloudwatch_log_group" "eks_scheduler" {
  name              = "/aws/eks/${var.cluster_name}/scheduler"
  retention_in_days = var.config.retention_days
  kms_key_id        = var.kms_key_id

  tags = local.common_tags
}

# CloudWatch Log Stream for structured audit logs
resource "aws_cloudwatch_log_stream" "audit_structured" {
  count          = var.config.enable_structured_logging ? 1 : 0
  name           = "audit-structured"
  log_group_name = aws_cloudwatch_log_group.eks_audit.name
}

# CloudWatch Metric Filter for security events
resource "aws_cloudwatch_log_metric_filter" "security_events" {
  count          = var.config.enable_security_monitoring ? 1 : 0
  name           = "${local.name_prefix}-security-events"
  log_group_name = aws_cloudwatch_log_group.eks_audit.name
  pattern        = "{ $.verb = \"create\" || $.verb = \"update\" || $.verb = \"delete\" }"

  metric_transformation {
    name      = "SecurityEvents"
    namespace = "EKS/Audit"
    value     = "1"
  }
}

# CloudWatch Metric Filter for failed authentication attempts
resource "aws_cloudwatch_log_metric_filter" "failed_auth" {
  count          = var.config.enable_security_monitoring ? 1 : 0
  name           = "${local.name_prefix}-failed-auth"
  log_group_name = aws_cloudwatch_log_group.eks_authenticator.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "FailedAuthentications"
    namespace = "EKS/Audit"
    value     = "1"
  }
}

# CloudWatch Alarm for high security events
resource "aws_cloudwatch_metric_alarm" "high_security_events" {
  count               = var.config.enable_alerting ? 1 : 0
  alarm_name          = "${local.name_prefix}-high-security-events"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SecurityEvents"
  namespace           = "EKS/Audit"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors high security events in EKS audit logs"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  tags = local.common_tags
}

# CloudWatch Alarm for failed authentications
resource "aws_cloudwatch_metric_alarm" "failed_authentications" {
  count               = var.config.enable_alerting ? 1 : 0
  alarm_name          = "${local.name_prefix}-failed-authentications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FailedAuthentications"
  namespace           = "EKS/Audit"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors failed authentications in EKS"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  tags = local.common_tags
}

# IAM role for audit log processing (if using Lambda)
resource "aws_iam_role" "audit_processor" {
  count = var.config.enable_log_processing ? 1 : 0
  name  = "${local.name_prefix}-audit-processor"

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

# IAM policy for audit log processing
resource "aws_iam_role_policy" "audit_processor" {
  count = var.config.enable_log_processing ? 1 : 0
  name  = "${local.name_prefix}-audit-processor"
  role  = aws_iam_role.audit_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.eks_audit.arn,
          aws_cloudwatch_log_group.eks_api.arn,
          aws_cloudwatch_log_group.eks_authenticator.arn,
          aws_cloudwatch_log_group.eks_controller_manager.arn,
          aws_cloudwatch_log_group.eks_scheduler.arn
        ]
      }
    ]
  })
}
