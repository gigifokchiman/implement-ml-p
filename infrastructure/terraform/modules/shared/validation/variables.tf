variable "cluster_interface" {
  description = "Cluster interface to validate"
  type = object({
    name        = string
    endpoint    = string
    version     = string
    vpc_id      = optional(string)
    is_ready    = bool
    is_aws      = bool
    is_local    = bool
  })
  default = null
}

variable "security_interface" {
  description = "Security interface to validate"
  type = object({
    certificates = object({
      enabled   = bool
      namespace = string
      issuer    = string
    })
    ingress = object({
      class     = string
      namespace = string
    })
    gitops = object({
      enabled   = bool
      namespace = string
    })
    is_ready = bool
  })
  default = null
}

variable "provider_config" {
  description = "Provider configuration to validate"
  type = object({
    vpc_id                = optional(string, "")
    subnet_ids            = optional(list(string), [])
    allowed_cidr_blocks   = optional(list(string), [])
    backup_retention_days = optional(number, 7)
    deletion_protection   = optional(bool, true)
    region                = optional(string, "")
  })
  default = null
}