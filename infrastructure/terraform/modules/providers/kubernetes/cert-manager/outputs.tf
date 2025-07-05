# Kubernetes Provider - Cert-Manager Outputs

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.config.enable_cert_manager
}

output "namespace" {
  description = "Cert-manager namespace"
  value       = var.config.enable_cert_manager ? "cert-manager" : null
}

output "ready" {
  description = "Whether cert-manager is ready"
  value       = var.config.enable_cert_manager ? true : false
}