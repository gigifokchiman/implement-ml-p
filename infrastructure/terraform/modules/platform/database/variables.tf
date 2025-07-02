variable "name" {
  description = "Database instance name"
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
  description = "CIDR blocks allowed to access database"
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}