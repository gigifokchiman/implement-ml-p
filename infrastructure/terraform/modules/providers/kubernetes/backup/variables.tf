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
    backup_schedule     = string
    retention_days      = number
    enable_cross_region = bool
    enable_encryption   = bool
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
