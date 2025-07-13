variable "name" {
  description = "Backup instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Backup configuration"
  type = object({
    # Common configuration
    backup_schedule     = optional(string, "cron(0 2 ? * * *)")
    retention_days      = optional(number, 30)
    enable_cross_region = optional(bool, false)
    enable_encryption   = optional(bool, true)

    # AWS-specific configuration
    kms_key_arn        = optional(string, null)
    backup_rule_name   = optional(string, "DailyBackup")
    cold_storage_after = optional(number, 30)
    delete_after       = optional(number, 365)
    backup_rds_enabled = optional(bool, true)
    backup_ebs_enabled = optional(bool, true)
  })
  default = {}
}

variable "database_arn" {
  description = "Database ARN for backup (AWS)"
  type        = string
  default     = ""
}

variable "storage_buckets" {
  description = "Storage buckets for backup (AWS)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
