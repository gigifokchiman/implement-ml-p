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
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}