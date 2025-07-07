variable "name" {
  description = "Cache instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "namespace"
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
    port      = optional(number, 6379)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
