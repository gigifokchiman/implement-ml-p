# Security Interface Definition
# Defines the contract for security service interfaces

variable "security_outputs" {
  description = "Security interface outputs"
  type = object({
    cert_manager_enabled     = bool
    cert_manager_namespace   = optional(string)
    cluster_issuer          = optional(string)
    ingress_class           = optional(string)
    ingress_namespace       = optional(string)
    argocd_enabled          = optional(bool)
    argocd_namespace        = optional(string)
    pod_security_enabled    = optional(bool)
    network_policies_enabled = optional(bool)
    rbac_enabled            = optional(bool)
  })
  default = null
}

locals {
  security_interface = var.security_outputs != null ? {
    # Certificate management
    certificates = {
      enabled   = var.security_outputs.cert_manager_enabled
      namespace = try(var.security_outputs.cert_manager_namespace, "cert-manager")
      issuer    = try(var.security_outputs.cluster_issuer, "selfsigned")
    }
    
    # Ingress management
    ingress = {
      class     = try(var.security_outputs.ingress_class, "nginx")
      namespace = try(var.security_outputs.ingress_namespace, "ingress-nginx")
    }
    
    # GitOps
    gitops = {
      enabled   = try(var.security_outputs.argocd_enabled, false)
      namespace = try(var.security_outputs.argocd_namespace, "argocd")
    }
    
    # Security policies
    policies = {
      pod_security      = try(var.security_outputs.pod_security_enabled, false)
      network_policies  = try(var.security_outputs.network_policies_enabled, false)
      rbac             = try(var.security_outputs.rbac_enabled, true)
    }
    
    # Helper functions
    is_ready = var.security_outputs.cert_manager_enabled != null
    has_tls  = var.security_outputs.cert_manager_enabled == true
  } : null
}

output "security_interface" {
  description = "Standardized security interface"
  value       = local.security_interface
}