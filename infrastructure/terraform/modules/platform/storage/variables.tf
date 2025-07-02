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

# AWS-specific variables (optional, only used for cloud environments)
variable "region" {
  description = "AWS region (for AWS environments)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}