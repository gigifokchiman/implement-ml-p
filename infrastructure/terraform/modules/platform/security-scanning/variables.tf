variable "name" {
  description = "Security scanning instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Security scanning configuration"
  type = object({
    enable_image_scanning   = bool
    enable_vulnerability_db = bool
    enable_runtime_scanning = bool
    enable_compliance_check = bool
    scan_schedule           = string
    severity_threshold      = string
    enable_notifications    = bool
    webhook_url             = optional(string)
  })
  default = {
    enable_image_scanning   = true
    enable_vulnerability_db = true
    enable_runtime_scanning = true
    enable_compliance_check = true
    scan_schedule           = "0 2 * * *" # Daily at 2 AM
    severity_threshold      = "HIGH"
    enable_notifications    = true
    webhook_url             = null
  }
}

variable "namespaces" {
  description = "List of namespaces to scan"
  type        = list(string)
  default     = ["database", "cache", "storage", "monitoring"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}