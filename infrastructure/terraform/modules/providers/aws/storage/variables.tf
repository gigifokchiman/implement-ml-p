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

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}