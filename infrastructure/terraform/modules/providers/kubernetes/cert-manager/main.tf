# Kubernetes Provider - Cert-Manager Implementation
# Handles cert-manager deployment via Helm on Kubernetes

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Cert-Manager Helm Release
resource "helm_release" "cert_manager" {
  count = var.config.enable_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.config.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  wait          = true
  wait_for_jobs = true
}

# Wait for cert-manager CRDs to be available
resource "time_sleep" "wait_for_cert_manager" {
  count           = var.config.enable_cert_manager ? 1 : 0
  depends_on      = [helm_release.cert_manager]
  create_duration = "120s"
}

# Namespace labeling
resource "kubernetes_labels" "cert_manager_namespace" {
  count = var.config.enable_cert_manager ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "cert-manager"
  }
  labels = merge(var.tags, {
    "name"                   = "cert-manager"
    "team"                   = "platform-engineering"
    "cost-center"            = "platform"
    "app.kubernetes.io/name" = "cert-manager"
  })

  depends_on = [time_sleep.wait_for_cert_manager]
}