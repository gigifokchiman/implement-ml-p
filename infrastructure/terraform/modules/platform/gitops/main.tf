# Platform GitOps Module
# Handles GitOps and continuous deployment infrastructure


# ArgoCD for GitOps
resource "helm_release" "argocd" {
  count = var.config.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.config.argocd_version
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = var.config.service_type
  }

  set {
    name  = "server.insecure"
    value = var.config.insecure
  }

  set {
    name  = "configs.params.server.insecure"
    value = var.config.insecure
  }

  wait          = true
  wait_for_jobs = true
}

# Wait for ArgoCD CRDs to be established
resource "time_sleep" "wait_for_argocd" {
  count = var.config.enable_argocd ? 1 : 0

  create_duration = "60s"
  depends_on      = [helm_release.argocd]
}

# Namespace labeling
resource "kubernetes_labels" "argocd_namespace" {
  count = var.config.enable_argocd ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "argocd"
  }
  labels = merge(var.tags, {
    "name"                   = "argocd"
    "team"                   = "platform-engineering"
    "cost-center"            = "platform"
    "app.kubernetes.io/name" = "argocd"
  })

  depends_on = [helm_release.argocd]
}
