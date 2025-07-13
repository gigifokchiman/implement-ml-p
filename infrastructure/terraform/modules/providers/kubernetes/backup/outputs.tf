output "backup_status" {
  description = "Backup status"
  value = {
    velero_installed = true
    backup_schedules = {
      database = "database-backup"
      storage  = "storage-backup"
      cache    = "cache-backup"
    }
    retention_days = var.config.retention_days
  }
}
