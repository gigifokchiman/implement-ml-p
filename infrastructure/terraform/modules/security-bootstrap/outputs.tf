# Security Bootstrap Module Outputs

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is deployed"
  value       = "cert-manager"
}

output "ingress_namespace" {
  description = "Namespace where NGINX ingress is deployed"
  value       = "ingress-nginx"
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = "argocd"
}

output "monitoring_namespace" {
  description = "Namespace where monitoring stack is deployed"
  value       = "monitoring"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = var.argocd_config.admin_password != "" ? var.argocd_config.admin_password : random_password.argocd_admin.result
  sensitive   = true
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.prometheus_config.grafana_admin_password
  sensitive   = true
}

output "cluster_issuer_name" {
  description = "Name of the cluster issuer for certificates"
  value       = var.environment == "local" ? "selfsigned" : "letsencrypt-prod"
}

output "ingress_class_name" {
  description = "Name of the ingress class"
  value       = "nginx"
}