variable "name" {
  description = "Security instance name"
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
}

variable "namespaces" {
  description = "List of namespaces to secure"
  type        = list(string)
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
