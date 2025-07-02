# AWS Security Scanning Implementation
# Uses AWS Inspector, ECR Image Scanning, and GuardDuty

# ECR Image Scanning Configuration
resource "aws_ecr_registry_scanning_configuration" "main" {
  count = var.config.enable_image_scanning ? 1 : 0

  scan_type = "ENHANCED"

  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }

  # Note: aws_ecr_registry_scanning_configuration does not support tags
}

# Inspector V2 Assessment Target
resource "aws_inspector2_enabler" "inspector" {
  count = var.config.enable_vulnerability_db ? 1 : 0

  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2", "ECR", "LAMBDA"]

  # Note: aws_inspector2_enabler does not support tags
}

# GuardDuty Detector
resource "aws_guardduty_detector" "main" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  # Note: datasources block is deprecated, use aws_guardduty_detector_feature resources instead

  tags = var.tags
}

# GuardDuty Detector Features (replaces deprecated datasources block)
resource "aws_guardduty_detector_feature" "s3_logs" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "kubernetes_audit_logs" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "malware_protection" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

# Security Hub for centralized findings
resource "aws_securityhub_account" "main" {
  count = var.config.enable_compliance_check ? 1 : 0

  enable_default_standards = true

  # Note: aws_securityhub_account does not support tags
}

# CloudWatch Log Group for security scanning logs
resource "aws_cloudwatch_log_group" "security_scanning" {
  name              = "/aws/security-scanning/${var.name}"
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = merge(var.tags, {
    Name        = "${var.name}-security-scanning-logs"
    Environment = var.environment
  })
}

# IAM Role for security scanning
resource "aws_iam_role" "security_scanning" {
  name = "${var.name}-security-scanning-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "inspector2.amazonaws.com",
            "guardduty.amazonaws.com",
            "securityhub.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for security scanning
resource "aws_iam_policy" "security_scanning" {
  name        = "${var.name}-security-scanning-policy"
  description = "Policy for security scanning services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "inspector2:BatchGetAccountStatus",
          "inspector2:GetFindings",
          "inspector2:ListFindings",
          "guardduty:GetDetector",
          "guardduty:GetFindings",
          "guardduty:ListFindings",
          "securityhub:GetFindings",
          "securityhub:BatchImportFindings",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "security_scanning" {
  role       = aws_iam_role.security_scanning.name
  policy_arn = aws_iam_policy.security_scanning.arn
}

# EventBridge Rule for security findings
resource "aws_cloudwatch_event_rule" "security_findings" {
  count = var.config.enable_notifications ? 1 : 0

  name        = "${var.name}-security-findings"
  description = "Capture security findings from Inspector, GuardDuty, and Security Hub"

  event_pattern = jsonencode({
    source      = ["aws.inspector2", "aws.guardduty", "aws.securityhub"]
    detail-type = ["Inspector2 Finding", "GuardDuty Finding", "Security Hub Findings - Imported"]
    detail = {
      severity = {
        label = [
          var.config.severity_threshold == "HIGH" ? ["HIGH", "CRITICAL"] :
          var.config.severity_threshold == "MEDIUM" ? ["MEDIUM", "HIGH", "CRITICAL"] :
          ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
        ][0]
      }
    }
  })

  tags = var.tags
}

# EventBridge Target for security findings (CloudWatch Logs)
resource "aws_cloudwatch_event_target" "security_findings_logs" {
  count = var.config.enable_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_findings[0].name
  target_id = "SecurityFindingsLogTarget"
  arn       = aws_cloudwatch_log_group.security_scanning.arn
}

# EventBridge Target for security findings (SNS if webhook provided)
resource "aws_sns_topic" "security_findings" {
  count = var.config.enable_notifications && var.config.webhook_url != null ? 1 : 0

  name = "${var.name}-security-findings"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "security_findings_webhook" {
  count = var.config.enable_notifications && var.config.webhook_url != null ? 1 : 0

  topic_arn = aws_sns_topic.security_findings[0].arn
  protocol  = "https"
  endpoint  = var.config.webhook_url
}

resource "aws_cloudwatch_event_target" "security_findings_sns" {
  count = var.config.enable_notifications && var.config.webhook_url != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_findings[0].name
  target_id = "SecurityFindingsSNSTarget"
  arn       = aws_sns_topic.security_findings[0].arn
}

# Lambda function for processing security findings (optional)
resource "aws_lambda_function" "security_processor" {
  count = var.config.enable_notifications ? 1 : 0

  filename      = data.archive_file.security_processor_zip[0].output_path
  function_name = "${var.name}-security-processor"
  role          = aws_iam_role.lambda_security_processor[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  source_code_hash = data.archive_file.security_processor_zip[0].output_base64sha256

  environment {
    variables = {
      LOG_GROUP_NAME     = aws_cloudwatch_log_group.security_scanning.name
      SEVERITY_THRESHOLD = var.config.severity_threshold
    }
  }

  tags = var.tags
}

# Lambda function code
data "archive_file" "security_processor_zip" {
  count = var.config.enable_notifications ? 1 : 0

  type        = "zip"
  output_path = "/tmp/security_processor.zip"
  source {
    content  = <<-EOT
import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """Process security findings and generate alerts"""
    
    logs_client = boto3.client('logs')
    log_group = os.environ['LOG_GROUP_NAME']
    severity_threshold = os.environ['SEVERITY_THRESHOLD']
    
    # Extract finding details
    detail = event.get('detail', {})
    source = event.get('source', '')
    
    # Prepare log message
    log_message = {
        'timestamp': datetime.utcnow().isoformat(),
        'source': source,
        'severity': detail.get('severity', {}).get('label', 'UNKNOWN'),
        'title': detail.get('title', 'Security Finding'),
        'description': detail.get('description', ''),
        'resource': detail.get('resource', {}),
        'region': detail.get('region', context.invoked_function_arn.split(':')[3]),
        'account': detail.get('account-id', context.invoked_function_arn.split(':')[4])
    }
    
    # Log to CloudWatch
    try:
        logs_client.put_log_events(
            logGroupName=log_group,
            logStreamName=f"security-findings-{datetime.utcnow().strftime('%Y-%m-%d')}",
            logEvents=[
                {
                    'timestamp': int(datetime.utcnow().timestamp() * 1000),
                    'message': json.dumps(log_message)
                }
            ]
        )
    except logs_client.exceptions.ResourceNotFoundException:
        # Create log stream if it doesn't exist
        logs_client.create_log_stream(
            logGroupName=log_group,
            logStreamName=f"security-findings-{datetime.utcnow().strftime('%Y-%m-%d')}"
        )
        logs_client.put_log_events(
            logGroupName=log_group,
            logStreamName=f"security-findings-{datetime.utcnow().strftime('%Y-%m-%d')}",
            logEvents=[
                {
                    'timestamp': int(datetime.utcnow().timestamp() * 1000),
                    'message': json.dumps(log_message)
                }
            ]
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Security finding processed successfully'})
    }
EOT
    filename = "index.py"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_security_processor" {
  count = var.config.enable_notifications ? 1 : 0

  name = "${var.name}-lambda-security-processor"

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
resource "aws_iam_policy" "lambda_security_processor" {
  count = var.config.enable_notifications ? 1 : 0

  name = "${var.name}-lambda-security-processor-policy"

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
          aws_cloudwatch_log_group.security_scanning.arn,
          "${aws_cloudwatch_log_group.security_scanning.arn}:*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_security_processor" {
  count = var.config.enable_notifications ? 1 : 0

  role       = aws_iam_role.lambda_security_processor[0].name
  policy_arn = aws_iam_policy.lambda_security_processor[0].arn
}

# EventBridge Target for Lambda
resource "aws_cloudwatch_event_target" "security_findings_lambda" {
  count = var.config.enable_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_findings[0].name
  target_id = "SecurityFindingsLambdaTarget"
  arn       = aws_lambda_function.security_processor[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.config.enable_notifications ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_processor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_findings[0].arn
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}