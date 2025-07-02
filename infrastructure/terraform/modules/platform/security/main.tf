# Platform-agnostic security interface
# Currently supports Kubernetes-based security

module "kubernetes_security" {
  source = "../../providers/kubernetes/security"

  name        = var.name
  environment = var.environment
  config      = var.config
  namespaces  = var.namespaces
  tags        = var.tags
}