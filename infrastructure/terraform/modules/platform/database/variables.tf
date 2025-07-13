variable "name" {
  description = "Database instance name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for database resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
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

# Provider configuration (platform-agnostic)
variable "provider_config" {
  description = "Provider-specific configuration"
  type = object({
    vpc_id                = optional(string, "")
    subnet_ids            = optional(list(string), [])
    allowed_cidr_blocks   = optional(list(string), [])
    backup_retention_days = optional(number, 7)
    deletion_protection   = optional(bool, true)
    region                = optional(string, "")
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
