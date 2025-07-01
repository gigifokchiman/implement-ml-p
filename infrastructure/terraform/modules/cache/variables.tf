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
  description = "Cache configuration"
  type = object({
    engine    = string
    version   = string
    node_type = string
    num_nodes = number
    encrypted = bool
  })
}

variable "subnet_ids" {
  description = "Subnet IDs for ElastiCache (cloud environments only)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for ElastiCache (cloud environments only)"
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for notifications (cloud environments only)"
  type        = string
  default     = null
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