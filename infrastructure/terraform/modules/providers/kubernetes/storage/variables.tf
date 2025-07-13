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
    # AWS-specific features (not used in Kubernetes/MinIO but kept for interface compatibility)
    versioning_enabled = optional(bool, false)
    encryption_enabled = optional(bool, false)
    lifecycle_enabled  = optional(bool, false)
    port               = optional(number, 9000)
    buckets = list(object({
      name   = string
      policy = optional(string, "private")
    }))
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
