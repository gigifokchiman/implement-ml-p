# Platform Certificate Management Outputs

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = module.kubernetes_cert_manager.cert_manager_enabled
}

output "cluster_issuer" {
  description = "Active cluster issuer name"
  value       = var.config.enable_selfsigned_issuer ? "selfsigned" : "letsencrypt-prod"
}

output "cert_manager_namespace" {
  description = "Cert-manager namespace"
  value       = module.kubernetes_cert_manager.namespace
}
