variable "name" {
  description = "Cache instance name"
  type        = string
}

variable "namespace" {
  description = "namespace name"
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

# Provider configuration (platform-agnostic)
variable "provider_config" {
  description = "Provider-specific configuration"
  type = object({
    vpc_id              = optional(string, "")
    subnet_ids          = optional(list(string), [])
    allowed_cidr_blocks = optional(list(string), [])
    region              = optional(string, "")
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
