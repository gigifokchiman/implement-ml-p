# Platform Ingress Controller Outputs

output "ingress_class" {
  description = "Ingress class name"
  value       = var.config.enable_nginx_ingress ? "nginx" : null
}

output "ingress_namespace" {
  description = "Ingress controller namespace"
  value       = var.config.enable_nginx_ingress ? "ingress-nginx" : null
}
