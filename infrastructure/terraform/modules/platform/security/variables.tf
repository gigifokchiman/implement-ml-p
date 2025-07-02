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
  default     = ["database", "cache", "storage", "monitoring"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}