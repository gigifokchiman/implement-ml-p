# Platform Security Bootstrap Variables

variable "name" {
  description = "Name of the security bootstrap"
  type        = string
}

variable "environment" {
  description = "Environment (injected for cross-cutting concerns only)"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

# Dependency injection interface
variable "cluster_info" {
  description = "Cluster interface for dependency injection"
  type = object({
    name     = string
    endpoint = string
    version  = string
    is_ready = bool
    is_aws   = bool
    is_local = bool
  })
  default = null
}

variable "config" {
  description = "Security bootstrap configuration"
  type = object({
    enable_cert_manager        = optional(bool, true)
    enable_pod_security        = optional(bool, true)
    enable_network_policies    = optional(bool, true)
    enable_rbac               = optional(bool, true)
    enable_argocd             = optional(bool, true)
    enable_letsencrypt_issuer = optional(bool, false)
    enable_selfsigned_issuer  = optional(bool, true)
    cert_manager_version      = optional(string, "v1.13.2")
    argocd_version           = optional(string, "5.51.6")
    pod_security_standard    = optional(string, "baseline")
    ingress_service_type     = optional(string, "LoadBalancer")
    ingress_host_port_enabled = optional(string, "false")
    argocd_service_type      = optional(string, "LoadBalancer")
    argocd_insecure          = optional(string, "false")
  })
  default = {
    enable_cert_manager        = true
    enable_pod_security        = true
    enable_network_policies    = true
    enable_rbac               = true
    enable_argocd             = true
    enable_letsencrypt_issuer = false
    enable_selfsigned_issuer  = true
    cert_manager_version      = "v1.13.2"
    argocd_version           = "5.51.6"
    pod_security_standard    = "baseline"
    ingress_service_type     = "LoadBalancer"
    ingress_host_port_enabled = "false"
    argocd_service_type      = "LoadBalancer"
    argocd_insecure          = "false"
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