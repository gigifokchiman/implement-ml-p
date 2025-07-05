# Platform GitOps Outputs

output "argocd_enabled" {
  description = "Whether ArgoCD is enabled"
  value       = var.config.enable_argocd
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.config.enable_argocd ? "argocd" : null
}