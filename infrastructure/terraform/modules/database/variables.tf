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

variable "database_password" {
  description = "Database password (will be generated if not provided)"
  type        = string
  default     = null
  sensitive   = true
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS (cloud environments only)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for RDS (cloud environments only)"
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable enhanced monitoring"
  type        = bool
  default     = true
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