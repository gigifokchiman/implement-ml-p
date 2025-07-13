# Platform Audit Logging Interface
# Provides unified interface for both AWS CloudWatch and Kubernetes audit logging


# AWS CloudWatch Audit Logging Provider
module "aws_audit_logging" {
  count  = var.use_aws ? 1 : 0
  source = "../../providers/aws/audit-logging"

  name         = var.name
  environment  = var.environment
  cluster_name = var.cluster_name

  config = {
    enable_api_audit           = var.config.enable_api_audit
    enable_webhook_audit       = var.config.enable_webhook_audit
    retention_days             = var.config.retention_days
    log_level                  = var.config.log_level
    enable_structured_logging  = var.environment == "prod"
    enable_security_monitoring = var.environment != "local"
    enable_alerting            = var.environment == "prod"
    enable_log_processing      = var.environment == "prod"
  }

  kms_key_id    = var.kms_key_id
  sns_topic_arn = var.sns_topic_arn

  tags = var.tags
}

# Kubernetes Audit Logging Provider
module "kubernetes_audit_logging" {
  count  = var.use_aws ? 0 : 1
  source = "../../providers/kubernetes/audit-logging"

  name         = var.name
  environment  = var.environment
  cluster_name = var.cluster_name

  config = {
    enable_api_audit      = var.config.enable_api_audit
    enable_webhook_audit  = var.config.enable_webhook_audit
    retention_days        = var.config.retention_days
    log_level             = var.config.log_level
    enable_log_collection = var.environment != "local"
  }

  tags = var.tags
}

# Output unified interface
locals {
  audit_logging_info = var.use_aws ? {
    provider_type  = "aws"
    namespace      = null
    log_groups     = module.aws_audit_logging[0].log_group_names
    log_group_arns = module.aws_audit_logging[0].log_group_arns
    metric_filters = module.aws_audit_logging[0].metric_filter_names
    alarms         = module.aws_audit_logging[0].alarm_names
    access_method  = "cloudwatch-logs"
    } : {
    provider_type  = "kubernetes"
    namespace      = module.kubernetes_audit_logging[0].namespace
    log_groups     = {}
    log_group_arns = {}
    metric_filters = {}
    alarms         = {}
    access_method  = "configmap-policy"
  }
}
