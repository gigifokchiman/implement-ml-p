# Platform Security Bootstrap Variables

variable "name" {
  description = "Name of the security bootstrap"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, local)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "config" {
  description = "Security bootstrap configuration"
  type = object({
    enable_cert_manager     = optional(bool, true)
    enable_pod_security     = optional(bool, true)
    enable_network_policies = optional(bool, true)
    enable_rbac            = optional(bool, true)
    cert_manager_version   = optional(string, "v1.13.2")
    pod_security_standard  = optional(string, "baseline")
  })
  default = {
    enable_cert_manager     = true
    enable_pod_security     = true
    enable_network_policies = true
    enable_rbac            = true
    cert_manager_version   = "v1.13.2"
    pod_security_standard  = "baseline"
  }
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}