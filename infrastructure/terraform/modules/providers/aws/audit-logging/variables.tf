# AWS Audit Logging Provider Variables

variable "name" {
  description = "Name of the audit logging setup"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, local)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "config" {
  description = "Audit logging configuration"
  type = object({
    enable_api_audit           = optional(bool, true)
    enable_webhook_audit       = optional(bool, false)
    retention_days             = optional(number, 30)
    log_level                  = optional(string, "Metadata")
    enable_structured_logging  = optional(bool, false)
    enable_security_monitoring = optional(bool, true)
    enable_alerting            = optional(bool, true)
    enable_log_processing      = optional(bool, false)
  })
  default = {
    enable_api_audit           = true
    enable_webhook_audit       = false
    retention_days             = 30
    log_level                  = "Metadata"
    enable_structured_logging  = false
    enable_security_monitoring = true
    enable_alerting            = true
    enable_log_processing      = false
  }
}

variable "kms_key_id" {
  description = "KMS key ID for log encryption"
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for audit alerts"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
