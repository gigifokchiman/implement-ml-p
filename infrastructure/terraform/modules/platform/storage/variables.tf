variable "name" {
  description = "Storage instance name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for storage resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Storage configuration"
  type = object({
    # AWS-specific features (optional for Kubernetes/MinIO compatibility)
    versioning_enabled = optional(bool, false)
    encryption_enabled = optional(bool, false)
    lifecycle_enabled  = optional(bool, false)
    port               = optional(number, 9000)
    buckets = list(object({
      name   = string
      policy = optional(string, "private") # Use policy instead of public for consistency
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
