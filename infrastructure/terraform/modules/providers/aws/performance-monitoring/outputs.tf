output "apm_endpoints" {
  description = "APM service endpoints"
  value = {
    application_insights = var.config.enable_apm ? aws_applicationinsights_application.main[0].id : null
    cloudwatch_dashboard = var.config.enable_apm ? "https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${aws_cloudwatch_dashboard.performance_dashboard[0].dashboard_name}" : null
    xray_console         = var.config.enable_distributed_trace ? "https://${data.aws_region.current.id}.console.aws.amazon.com/xray/home?region=${data.aws_region.current.id}#/service-map" : null
  }
}

output "tracing_endpoints" {
  description = "Distributed tracing endpoints"
  value = {
    xray_daemon_endpoint = var.config.enable_distributed_trace ? "https://xray.${data.aws_region.current.id}.amazonaws.com" : null
    sampling_rule        = var.config.enable_distributed_trace ? aws_xray_sampling_rule.main[0].arn : null
  }
}

output "metrics_endpoints" {
  description = "Custom metrics endpoints"
  value = {
    api_gateway_url   = var.config.enable_custom_metrics ? aws_api_gateway_stage.metrics_api[0].invoke_url : null
    metrics_namespace = var.config.enable_custom_metrics ? "CustomApp/${var.name}" : null
    lambda_function   = var.config.enable_custom_metrics ? aws_lambda_function.metrics_processor[0].function_name : null
  }
}

output "dashboards" {
  description = "Available performance monitoring dashboards"
  value = [
    var.config.enable_apm ? {
      name        = "CloudWatch Performance Dashboard"
      url         = "https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${aws_cloudwatch_dashboard.performance_dashboard[0].dashboard_name}"
      description = "Application performance metrics and logs"
    } : null,
    var.config.enable_distributed_trace ? {
      name        = "X-Ray Service Map"
      url         = "https://${data.aws_region.current.id}.console.aws.amazon.com/xray/home?region=${data.aws_region.current.id}#/service-map"
      description = "Distributed tracing and service dependencies"
    } : null,
    var.config.enable_apm ? {
      name        = "Application Insights"
      url         = "https://${data.aws_region.current.id}.console.aws.amazon.com/systems-manager/appinsights/application/${aws_applicationinsights_application.main[0].id}"
      description = "Application performance insights and anomaly detection"
    } : null
  ]
}

output "useful_commands" {
  description = "Useful commands for performance monitoring operations"
  value = [
    "# View CloudWatch logs",
    var.config.enable_log_aggregation ? "aws logs describe-log-streams --log-group-name ${aws_cloudwatch_log_group.application_logs[0].name}" : null,
    "# Get CloudWatch metrics",
    var.config.enable_custom_metrics ? "aws cloudwatch get-metric-statistics --namespace CustomApp/${var.name} --metric-name <metric-name> --start-time <start> --end-time <end> --period 300 --statistics Average" : null,
    "# Send custom metric via API",
    var.config.enable_custom_metrics ? "curl -X POST ${aws_api_gateway_stage.metrics_api[0].invoke_url}/metrics -H 'Content-Type: application/json' -d '{\"metric_name\":\"test_metric\",\"value\":1,\"unit\":\"Count\"}'" : null,
    "# View X-Ray traces",
    var.config.enable_distributed_trace ? "aws xray get-trace-summaries --time-range-type TimeRangeByStartTime --start-time <start> --end-time <end>" : null,
    "# Invoke metrics processor directly",
    var.config.enable_custom_metrics ? "aws lambda invoke --function-name ${aws_lambda_function.metrics_processor[0].function_name} --payload '{\"metric_name\":\"test\",\"value\":1}' response.json" : null
  ]
}