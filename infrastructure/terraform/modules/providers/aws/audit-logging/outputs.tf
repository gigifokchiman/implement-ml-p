# AWS Audit Logging Provider Outputs

output "log_group_names" {
  description = "Names of CloudWatch log groups"
  value = {
    audit              = aws_cloudwatch_log_group.eks_audit.name
    api                = aws_cloudwatch_log_group.eks_api.name
    authenticator      = aws_cloudwatch_log_group.eks_authenticator.name
    controller_manager = aws_cloudwatch_log_group.eks_controller_manager.name
    scheduler          = aws_cloudwatch_log_group.eks_scheduler.name
  }
}

output "log_group_arns" {
  description = "ARNs of CloudWatch log groups"
  value = {
    audit              = aws_cloudwatch_log_group.eks_audit.arn
    api                = aws_cloudwatch_log_group.eks_api.arn
    authenticator      = aws_cloudwatch_log_group.eks_authenticator.arn
    controller_manager = aws_cloudwatch_log_group.eks_controller_manager.arn
    scheduler          = aws_cloudwatch_log_group.eks_scheduler.arn
  }
}

output "log_stream_names" {
  description = "Names of CloudWatch log streams"
  value = var.config.enable_structured_logging ? {
    audit_structured = aws_cloudwatch_log_stream.audit_structured[0].name
  } : {}
}

output "metric_filter_names" {
  description = "Names of CloudWatch metric filters"
  value = var.config.enable_security_monitoring ? {
    security_events = aws_cloudwatch_log_metric_filter.security_events[0].name
    failed_auth     = aws_cloudwatch_log_metric_filter.failed_auth[0].name
  } : {}
}

output "alarm_names" {
  description = "Names of CloudWatch alarms"
  value = var.config.enable_alerting ? {
    high_security_events   = aws_cloudwatch_metric_alarm.high_security_events[0].alarm_name
    failed_authentications = aws_cloudwatch_metric_alarm.failed_authentications[0].alarm_name
  } : {}
}

output "processor_role_arn" {
  description = "ARN of the audit processor IAM role"
  value       = var.config.enable_log_processing ? aws_iam_role.audit_processor[0].arn : null
}
