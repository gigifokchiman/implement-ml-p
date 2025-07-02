output "backup_schedule" {
  description = "Backup schedule"
  value       = var.config.backup_schedule
}

output "retention_days" {
  description = "Backup retention days"
  value       = var.config.retention_days
}

output "backup_status" {
  description = "Backup status"
  value = local.is_local ? (
    length(module.kubernetes_backup) > 0 ? "Velero backup enabled" : "No backup configured"
    ) : (
    length(module.aws_backup) > 0 ? "AWS Backup enabled" : "No backup configured"
  )
}