output "scanner_endpoints" {
  description = "Security scanner service endpoints"
  value = {
    ecr_registry_scanning = var.config.enable_image_scanning ? "ECR Enhanced Scanning enabled for all repositories" : null
    inspector_v2          = var.config.enable_vulnerability_db ? "AWS Inspector V2 enabled for EC2, ECR, and Lambda" : null
    guardduty             = var.config.enable_runtime_scanning ? aws_guardduty_detector.main[0].id : null
    security_hub          = var.config.enable_compliance_check ? aws_securityhub_account.main[0].id : null
  }
}

output "vulnerability_database" {
  description = "Vulnerability database information"
  value = {
    ecr_scanning_enabled = var.config.enable_image_scanning
    inspector_enabled    = var.config.enable_vulnerability_db
    guardduty_enabled    = var.config.enable_runtime_scanning
    security_hub_enabled = var.config.enable_compliance_check
  }
}

output "scan_reports_location" {
  description = "Location where scan reports are stored"
  value       = aws_cloudwatch_log_group.security_scanning.name
}

output "useful_commands" {
  description = "Useful commands for security scanning operations"
  value = [
    "# View security scanning logs",
    "aws logs describe-log-streams --log-group-name ${aws_cloudwatch_log_group.security_scanning.name}",
    "# Get ECR scan results",
    "aws ecr describe-image-scan-findings --repository-name <repo-name> --image-id imageTag=<tag>",
    "# Get Inspector findings",
    "aws inspector2 list-findings --filter-criteria '{}' --max-results 50",
    "# Get GuardDuty findings",
    var.config.enable_runtime_scanning ? "aws guardduty list-findings --detector-id ${aws_guardduty_detector.main[0].id}" : null,
    "# Get Security Hub findings",
    var.config.enable_compliance_check ? "aws securityhub get-findings --max-results 50" : null
  ]
}