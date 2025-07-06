# Service Registry Variables

variable "platform_name" {
  description = "Name of the platform"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "registry_namespace" {
  description = "Namespace for service registry"
  type        = string
  default     = "platform-system"
}

# Service interfaces for registration
variable "cluster_service" {
  description = "Cluster service interface"
  type = object({
    name     = string
    endpoint = string
    version  = string
    is_ready = bool
    is_aws   = bool
    vpc_id   = optional(string)
    region   = optional(string)
  })
  default = null
}

variable "security_service" {
  description = "Security service interface"
  type = object({
    is_ready = bool
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
  })
  default = null
}

variable "additional_services" {
  description = "Additional services to register"
  type = map(object({
    name     = string
    type     = string
    status   = string
    endpoint = optional(string)
    metadata = optional(map(string), {})
  }))
  default = {}
}

variable "enable_health_checks" {
  description = "Enable health checks for registered services"
  type        = bool
  default     = false  # Disabled - managed by ArgoCD
}

variable "enable_service_registry" {
  description = "Enable service registry ConfigMap creation"
  type        = bool
  default     = false  # Disabled until namespace exists
}