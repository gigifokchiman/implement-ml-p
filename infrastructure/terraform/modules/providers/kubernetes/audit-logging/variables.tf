# Kubernetes Audit Logging Provider Variables

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

variable "config" {
  description = "Audit logging configuration"
  type = object({
    enable_api_audit      = optional(bool, true)
    enable_webhook_audit  = optional(bool, false)
    retention_days        = optional(number, 30)
    log_level             = optional(string, "Metadata")
    enable_log_collection = optional(bool, false)
  })
  default = {
    enable_api_audit      = true
    enable_webhook_audit  = false
    retention_days        = 30
    log_level             = "Metadata"
    enable_log_collection = false
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
