# AWS Performance Monitoring Implementation
# Uses AWS X-Ray for tracing, CloudWatch for metrics and logs, and AppInsights for APM

# X-Ray Service Map and Tracing
resource "aws_xray_sampling_rule" "main" {
  count = var.config.enable_distributed_trace ? 1 : 0

  rule_name      = "${var.name}-sampling-rule"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = var.config.sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = var.tags
}

# CloudWatch Log Groups for different services
resource "aws_cloudwatch_log_group" "application_logs" {
  count = var.config.enable_log_aggregation ? 1 : 0

  name              = "/aws/application/${var.name}"
  retention_in_days = var.config.retention_days

  tags = merge(var.tags, {
    Name        = "${var.name}-application-logs"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "performance_logs" {
  count = var.config.enable_apm ? 1 : 0

  name              = "/aws/performance/${var.name}"
  retention_in_days = var.config.retention_days

  tags = merge(var.tags, {
    Name        = "${var.name}-performance-logs"
    Environment = var.environment
  })
}

# CloudWatch Custom Metrics Namespace
resource "aws_cloudwatch_composite_alarm" "application_health" {
  count = var.config.enable_alerting ? 1 : 0

  alarm_name        = "${var.name}-application-health"
  alarm_description = "Composite alarm for application health monitoring"

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.high_error_rate[0].alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.high_latency[0].alarm_name})"

  actions_enabled = true
  alarm_actions   = [aws_sns_topic.performance_alerts[0].arn]
  ok_actions      = [aws_sns_topic.performance_alerts[0].arn]

  tags = var.tags
}

# CloudWatch Metric Alarms
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count = var.config.enable_alerting ? 1 : 0

  alarm_name          = "${var.name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorRate"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors application error rate"
  alarm_actions       = [aws_sns_topic.performance_alerts[0].arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  count = var.config.enable_alerting ? 1 : 0

  alarm_name          = "${var.name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors application response time"
  alarm_actions       = [aws_sns_topic.performance_alerts[0].arn]

  tags = var.tags
}

# SNS Topic for Performance Alerts
resource "aws_sns_topic" "performance_alerts" {
  count = var.config.enable_alerting ? 1 : 0

  name = "${var.name}-performance-alerts"

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "performance_dashboard" {
  count = var.config.enable_apm ? 1 : 0

  dashboard_name = "${var.name}-performance-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount"],
            ["AWS/ApplicationELB", "TargetResponseTime"],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count"],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count"],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization"],
            ["AWS/RDS", "DatabaseConnections"],
            ["AWS/RDS", "ReadLatency"],
            ["AWS/RDS", "WriteLatency"]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.id
          title  = "Database Performance Metrics"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization"],
            ["AWS/ElastiCache", "NetworkBytesIn"],
            ["AWS/ElastiCache", "NetworkBytesOut"],
            ["AWS/ElastiCache", "CacheHitRate"]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.id
          title  = "Cache Performance Metrics"
          period = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6

        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.application_logs[0].name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region = data.aws_region.current.id
          title  = "Recent Application Logs"
          view   = "table"
        }
      }
    ]
  })

  # Note: aws_cloudwatch_dashboard does not support tags
}

# Application Insights for APM
resource "aws_applicationinsights_application" "main" {
  count = var.config.enable_apm ? 1 : 0

  resource_group_name = aws_resourcegroups_group.main[0].name
  auto_config_enabled = true
  cwe_monitor_enabled = true
  ops_center_enabled  = true

  # Note: log_pattern block is not supported in aws_applicationinsights_application
  # Application Insights will auto-discover log patterns

  tags = var.tags
}

# Resource Group for Application Insights
resource "aws_resourcegroups_group" "main" {
  count = var.config.enable_apm ? 1 : 0

  name = "${var.name}-performance-monitoring"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Environment"
          Values = [var.environment]
        },
        {
          Key    = "Application"
          Values = [var.name]
        }
      ]
    })
  }

  tags = var.tags
}

# Lambda function for custom metrics processing
resource "aws_lambda_function" "metrics_processor" {
  count = var.config.enable_custom_metrics ? 1 : 0

  filename      = data.archive_file.metrics_processor_zip[0].output_path
  function_name = "${var.name}-metrics-processor"
  role          = aws_iam_role.lambda_metrics_processor[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  source_code_hash = data.archive_file.metrics_processor_zip[0].output_base64sha256

  environment {
    variables = {
      CLOUDWATCH_NAMESPACE = "CustomApp/${var.name}"
      ENVIRONMENT          = var.environment
    }
  }

  tags = var.tags
}

# Lambda function code for metrics processing
data "archive_file" "metrics_processor_zip" {
  count = var.config.enable_custom_metrics ? 1 : 0

  type        = "zip"
  output_path = "/tmp/metrics_processor.zip"
  source {
    content  = <<-EOT
import json
import boto3
import os
from datetime import datetime, timezone

cloudwatch = boto3.client('cloudwatch')

def handler(event, context):
    """Process custom application metrics and send to CloudWatch"""
    
    namespace = os.environ['CLOUDWATCH_NAMESPACE']
    environment = os.environ['ENVIRONMENT']
    
    # Process different types of metrics
    if 'Records' in event:
        # Processing SQS/SNS messages with metrics
        for record in event['Records']:
            try:
                if 'body' in record:
                    message = json.loads(record['body'])
                elif 'Message' in record:
                    message = json.loads(record['Message'])
                else:
                    continue
                    
                process_metric(message, namespace, environment)
                
            except Exception as e:
                print(f"Error processing record: {e}")
                continue
    else:
        # Direct invocation with metrics
        process_metric(event, namespace, environment)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Metrics processed successfully')
    }

def process_metric(metric_data, namespace, environment):
    """Process individual metric and send to CloudWatch"""
    
    try:
        metric_name = metric_data.get('metric_name', 'CustomMetric')
        value = float(metric_data.get('value', 0))
        unit = metric_data.get('unit', 'Count')
        dimensions = metric_data.get('dimensions', {})
        
        # Add environment dimension
        dimensions['Environment'] = environment
        
        # Convert dimensions to CloudWatch format
        cw_dimensions = [
            {'Name': k, 'Value': str(v)} for k, v in dimensions.items()
        ]
        
        # Send metric to CloudWatch
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Dimensions': cw_dimensions,
                    'Timestamp': datetime.now(timezone.utc)
                }
            ]
        )
        
        print(f"Sent metric {metric_name}: {value} {unit}")
        
    except Exception as e:
        print(f"Error processing metric: {e}")
        raise
EOT
    filename = "index.py"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_metrics_processor" {
  count = var.config.enable_custom_metrics ? 1 : 0

  name = "${var.name}-lambda-metrics-processor"

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

  tags = var.tags
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_metrics_processor" {
  count = var.config.enable_custom_metrics ? 1 : 0

  name = "${var.name}-lambda-metrics-processor-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.performance_logs[0].arn,
          "${aws_cloudwatch_log_group.performance_logs[0].arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CustomApp/${var.name}"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_metrics_processor" {
  count = var.config.enable_custom_metrics ? 1 : 0

  role       = aws_iam_role.lambda_metrics_processor[0].name
  policy_arn = aws_iam_policy.lambda_metrics_processor[0].arn
}

# API Gateway for metrics ingestion
resource "aws_api_gateway_rest_api" "metrics_api" {
  count = var.config.enable_custom_metrics ? 1 : 0

  name        = "${var.name}-metrics-api"
  description = "API for custom metrics ingestion"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "metrics" {
  count = var.config.enable_custom_metrics ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.metrics_api[0].id
  parent_id   = aws_api_gateway_rest_api.metrics_api[0].root_resource_id
  path_part   = "metrics"
}

resource "aws_api_gateway_method" "metrics_post" {
  count = var.config.enable_custom_metrics ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.metrics_api[0].id
  resource_id   = aws_api_gateway_resource.metrics[0].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "metrics_integration" {
  count = var.config.enable_custom_metrics ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.metrics_api[0].id
  resource_id = aws_api_gateway_resource.metrics[0].id
  http_method = aws_api_gateway_method.metrics_post[0].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.metrics_processor[0].invoke_arn
}

resource "aws_api_gateway_deployment" "metrics_api" {
  count = var.config.enable_custom_metrics ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.metrics_api[0].id
  # Note: stage_name is deprecated, use aws_api_gateway_stage resource instead

  depends_on = [aws_api_gateway_integration.metrics_integration]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.metrics[0].id,
      aws_api_gateway_method.metrics_post[0].id,
      aws_api_gateway_integration.metrics_integration[0].id,
    ]))
  }
}

# API Gateway Stage (replaces deprecated stage_name in deployment)
resource "aws_api_gateway_stage" "metrics_api" {
  count = var.config.enable_custom_metrics ? 1 : 0

  deployment_id = aws_api_gateway_deployment.metrics_api[0].id
  rest_api_id   = aws_api_gateway_rest_api.metrics_api[0].id
  stage_name    = var.environment

  tags = var.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "allow_api_gateway" {
  count = var.config.enable_custom_metrics ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.metrics_processor[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.metrics_api[0].execution_arn}/*/*"
}

# Data source for current region
data "aws_region" "current" {}