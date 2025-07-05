# Platform Security Bootstrap Outputs

output "cert_manager_namespace" {
  description = "Cert-manager namespace"
  value       = var.config.enable_cert_manager ? "cert-manager" : null
}

output "ingress_namespace" {
  description = "Ingress controller namespace"
  value       = "ingress-nginx"
}

output "cluster_issuer" {
  description = "Default cluster issuer name"
  value       = local.security_bootstrap_info.cluster_issuer
}

output "ingress_class" {
  description = "Ingress class name"
  value       = local.security_bootstrap_info.ingress_class
}

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = local.security_bootstrap_info.cert_manager_enabled
}

output "pod_security_enabled" {
  description = "Whether pod security policies are enabled"
  value       = local.security_bootstrap_info.pod_security_enabled
}

output "network_policies_enabled" {
  description = "Whether network policies are enabled"
  value       = local.security_bootstrap_info.network_policies_enabled
}

output "rbac_enabled" {
  description = "Whether RBAC is enabled"
  value       = local.security_bootstrap_info.rbac_enabled
}

output "configuration" {
  description = "Security bootstrap configuration summary"
  value       = local.security_bootstrap_info
}