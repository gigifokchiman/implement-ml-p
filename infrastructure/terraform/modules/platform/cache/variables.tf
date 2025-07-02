variable "name" {
  description = "Cache instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
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
  description = "CIDR blocks allowed to access cache"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}