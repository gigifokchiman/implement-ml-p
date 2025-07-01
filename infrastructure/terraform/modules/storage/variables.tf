variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace (for local environment)"
  type        = string
  default     = "ml-platform"
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

variable "development_mode" {
  description = "Enable development mode with minimal resources"
  type        = bool
  default     = false
}

variable "local_storage_class" {
  description = "Storage class for local environment PVCs"
  type        = string
  default     = "standard"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}