# Platform Audit Logging Outputs

output "provider_type" {
  description = "Type of audit logging provider (aws or kubernetes)"
  value       = local.audit_logging_info.provider_type
}

output "namespace" {
  description = "Kubernetes namespace (for Kubernetes provider)"
  value       = local.audit_logging_info.namespace
}

output "log_groups" {
  description = "CloudWatch log groups (for AWS provider)"
  value       = local.audit_logging_info.log_groups
}

output "log_group_arns" {
  description = "ARNs of CloudWatch log groups (for AWS provider)"
  value       = local.audit_logging_info.log_group_arns
}

output "metric_filters" {
  description = "CloudWatch metric filters (for AWS provider)"
  value       = local.audit_logging_info.metric_filters
}

output "alarms" {
  description = "CloudWatch alarms (for AWS provider)"
  value       = local.audit_logging_info.alarms
}

output "access_method" {
  description = "Method for accessing audit logs"
  value       = local.audit_logging_info.access_method
}

# AWS-specific outputs
output "aws_audit_logging_outputs" {
  description = "AWS audit logging outputs"
  value = var.use_aws ? {
    log_group_names = module.aws_audit_logging[0].log_group_names
    log_group_arns  = module.aws_audit_logging[0].log_group_arns
    metric_filters  = module.aws_audit_logging[0].metric_filter_names
    alarms          = module.aws_audit_logging[0].alarm_names
    processor_role  = module.aws_audit_logging[0].processor_role_arn
  } : null
}

# Kubernetes-specific outputs
output "kubernetes_audit_logging_outputs" {
  description = "Kubernetes audit logging outputs"
  value = var.use_aws ? null : {
    namespace         = module.kubernetes_audit_logging[0].namespace
    config_map_names  = module.kubernetes_audit_logging[0].config_map_names
    service_account   = module.kubernetes_audit_logging[0].service_account_name
    daemonset_name    = module.kubernetes_audit_logging[0].daemonset_name
    cluster_role_name = module.kubernetes_audit_logging[0].cluster_role_name
    audit_policy_path = module.kubernetes_audit_logging[0].audit_policy_path
  }
}
