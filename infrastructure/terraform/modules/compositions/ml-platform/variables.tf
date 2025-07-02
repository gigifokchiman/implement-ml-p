variable "name" {
  description = "Platform name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    engine         = string
    version        = string
    instance_class = string
    storage_size   = number
    multi_az       = bool
    encrypted      = bool
    username       = string
    database_name  = string
  })
}

variable "cache_config" {
  description = "Cache configuration"
  type = object({
    engine    = string
    version   = string
    node_type = string
    num_nodes = number
    encrypted = bool
  })
}

variable "storage_config" {
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
variable "vpc_id" {
  description = "VPC ID (for AWS environments)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs (for AWS environments)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region (for AWS environments)"
  type        = string
  default     = ""
}

variable "security_webhook_url" {
  description = "Webhook URL for security notifications (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}