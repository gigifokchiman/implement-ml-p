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
    port           = optional(number, 5432)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}