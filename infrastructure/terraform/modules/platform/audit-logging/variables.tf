# Platform Audit Logging Variables

variable "name" {
  description = "Name of the audit logging setup"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, local)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "use_aws" {
  description = "Whether to use AWS providers (true) or Kubernetes providers (false)"
  type        = bool
  default     = false
}

variable "config" {
  description = "Audit logging configuration"
  type = object({
    enable_api_audit     = optional(bool, true)
    enable_webhook_audit = optional(bool, false)
    retention_days       = optional(number, 30)
    log_level            = optional(string, "Metadata")
  })
  default = {
    enable_api_audit     = true
    enable_webhook_audit = false
    retention_days       = 30
    log_level            = "Metadata"
  }
}

# AWS-specific variables
variable "kms_key_id" {
  description = "KMS key ID for log encryption (AWS only)"
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for audit alerts (AWS only)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
