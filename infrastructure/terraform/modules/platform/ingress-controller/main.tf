# Platform Ingress Controller Module
# Handles ingress management infrastructure


# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  count = var.config.enable_nginx_ingress ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.config.nginx_version
  namespace        = "ingress-nginx"
  create_namespace = true

  # Configuration via variables
  set {
    name  = "controller.service.type"
    value = var.config.service_type
  }

  set {
    name  = "controller.hostPort.enabled"
    value = var.config.host_port_enabled
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  wait          = true
  wait_for_jobs = true
}

# Namespace labeling
resource "kubernetes_labels" "ingress_nginx_namespace" {
  count = var.config.enable_nginx_ingress ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "ingress-nginx"
  }
  labels = merge(var.tags, {
    "name"                   = "ingress-nginx"
    "team"                   = "platform-engineering"
    "cost-center"            = "platform"
    "app.kubernetes.io/name" = "ingress-nginx"
  })

  depends_on = [helm_release.nginx_ingress]
}
