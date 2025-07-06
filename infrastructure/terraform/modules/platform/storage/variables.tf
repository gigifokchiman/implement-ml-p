variable "name" {
  description = "Storage instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Storage configuration"
  type = object({
    versioning_enabled = bool
    encryption_enabled = bool
    lifecycle_enabled  = bool
    buckets = list(object({
      name   = string
      public = bool
    }))
  })
}

# Provider configuration (platform-agnostic)
variable "provider_config" {
  description = "Provider-specific configuration"
  type = object({
    region = optional(string, "")
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}