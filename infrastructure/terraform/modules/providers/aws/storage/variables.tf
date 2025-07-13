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

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
