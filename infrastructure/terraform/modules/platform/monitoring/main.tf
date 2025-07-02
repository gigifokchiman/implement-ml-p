# Platform-agnostic monitoring interface
# Currently only supports Kubernetes as monitoring is typically K8s-based

module "kubernetes_monitoring" {
  source = "../../providers/kubernetes/monitoring"

  name        = var.name
  environment = var.environment
  config      = var.config
  tags        = var.tags
}