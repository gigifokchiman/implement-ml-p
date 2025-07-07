variable "name" {
  description = "Security instance name"
  type        = string
}

variable "namespace" {
  description = "Security instance namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Security configuration"
  type = object({
    enable_network_policies  = bool
    enable_pod_security      = bool
    enable_admission_control = bool
    pod_security_standard    = string
  })
  default = {
    enable_network_policies  = true
    enable_pod_security      = true
    enable_admission_control = true
    pod_security_standard    = "restricted"
  }
}

variable "namespaces" {
  description = "List of namespaces to secure"
  type        = list(string)
  default     = []
}

variable "platform_namespace" {
  description = "Shared data platform namespace for cache, database, storage components"
  type        = string
}

variable "monitoring_namespace" {
  description = "Monitoring namespace"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
