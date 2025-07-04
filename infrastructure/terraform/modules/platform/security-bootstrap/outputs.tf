output "cert_manager_namespace" {
  description = "Cert-manager namespace"
  value       = "cert-manager"
}

output "ingress_namespace" {
  description = "Ingress controller namespace"
  value       = "ingress-nginx"
}

output "cluster_issuer" {
  description = "Default cluster issuer name"
  value       = var.is_kind_cluster ? "selfsigned" : "letsencrypt-prod"
}

output "ingress_class" {
  description = "Ingress class name"
  value       = "nginx"
}