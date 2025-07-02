variable "name" {
  description = "Name prefix for backup resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for backup encryption"
  type        = string
  default     = null
}

variable "backup_rule_name" {
  description = "Name of the backup rule"
  type        = string
  default     = "DailyBackup"
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "cron(0 2 ? * * *)" # Daily at 2 AM
}

variable "cold_storage_after" {
  description = "Days after which to move backups to cold storage"
  type        = number
  default     = 30
}

variable "delete_after" {
  description = "Days after which to delete backups"
  type        = number
  default     = 365
}

variable "backup_rds_enabled" {
  description = "Enable backup for RDS databases"
  type        = bool
  default     = true
}

variable "backup_ebs_enabled" {
  description = "Enable backup for EBS volumes"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}