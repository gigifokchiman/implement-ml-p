# Cross-Cutting Concerns Variables

variable "platform_name" {
  description = "Name of the platform"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "module_name" {
  description = "Name of the calling module"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "instance_name" {
  description = "Instance name for the service"
  type        = string
  default     = "default"
}

variable "service_version" {
  description = "Version of the service"
  type        = string
  default     = "latest"
}

variable "component_type" {
  description = "Type of component (database, cache, storage, etc.)"
  type        = string
}

variable "service_type" {
  description = "Type of service (platform, application, infrastructure)"
  type        = string
  default     = "platform"
}

variable "service_tier" {
  description = "Service tier (core, optional, addon)"
  type        = string
  default     = "core"
}

variable "security_level" {
  description = "Security level (high, medium, low)"
  type        = string
  default     = "medium"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "base_tags" {
  description = "Base tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "logging_config" {
  description = "Logging configuration"
  type = object({
    enabled        = optional(bool, true)
    level          = optional(string, "info")
    destinations   = optional(list(string), ["stdout"])
    retention_days = optional(number, 30)
  })
  default = {}
}

variable "monitoring_config" {
  description = "Monitoring configuration"
  type = object({
    enabled            = optional(bool, true)
    metrics_enabled    = optional(bool, true)
    alerts_enabled     = optional(bool, true)
    dashboards_enabled = optional(bool, true)
  })
  default = {}
}

variable "security_config" {
  description = "Security configuration"
  type = object({
    pod_security_enabled     = optional(bool, true)
    network_policies_enabled = optional(bool, true)
    rbac_enabled             = optional(bool, true)
  })
  default = {}
}

variable "enable_service_discovery" {
  description = "Enable service discovery labels"
  type        = bool
  default     = true
}

variable "expose_metrics" {
  description = "Expose metrics endpoint"
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "Network policy ingress rules"
  type = list(object({
    from = optional(list(object({
      namespaceSelector = optional(object({
        matchLabels = optional(map(string))
      }))
      podSelector = optional(object({
        matchLabels = optional(map(string))
      }))
    })))
    ports = optional(list(object({
      protocol = optional(string, "TCP")
      port     = optional(number)
    })))
  }))
  default = []
}

variable "egress_rules" {
  description = "Network policy egress rules"
  type = list(object({
    to = optional(list(object({
      namespaceSelector = optional(object({
        matchLabels = optional(map(string))
      }))
      podSelector = optional(object({
        matchLabels = optional(map(string))
      }))
    })))
    ports = optional(list(object({
      protocol = optional(string, "TCP")
      port     = optional(number)
    })))
  }))
  default = [
    {
      # Allow all egress by default (can be restricted per service)
    }
  ]
}
