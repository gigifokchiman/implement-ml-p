# Security Infrastructure Bootstrap Module
# Deploys core security infrastructure via Terraform

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

# Cert-Manager for TLS certificate management
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.13.2"
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

  wait = true
  wait_for_jobs = true
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.8.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  # Kind-specific configuration
  dynamic "set" {
    for_each = var.is_kind_cluster ? [1] : []
    content {
      name  = "controller.service.type"
      value = "NodePort"
    }
  }

  dynamic "set" {
    for_each = var.is_kind_cluster ? [1] : []
    content {
      name  = "controller.hostPort.enabled"
      value = "true"
    }
  }

  # Production configuration
  dynamic "set" {
    for_each = var.is_kind_cluster ? [] : [1]
    content {
      name  = "controller.service.type"
      value = "LoadBalancer"
    }
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  depends_on = [helm_release.cert_manager]

  wait = true
  wait_for_jobs = true
}

# ClusterIssuer for Let's Encrypt (production clusters)
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.enable_letsencrypt ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
      labels = var.common_labels
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [time_sleep.wait_for_cert_manager]
}

# Wait for cert-manager CRDs to be available
resource "time_sleep" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]
  create_duration = "90s"
}

# Self-signed issuer for local development
resource "kubernetes_manifest" "selfsigned_issuer" {
  count = var.is_kind_cluster ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned"
      labels = var.common_labels
    }
    spec = {
      selfSigned = {}
    }
  }

  depends_on = [time_sleep.wait_for_cert_manager]
}

# Namespace labeling for security policies
resource "kubernetes_labels" "cert_manager_namespace" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "cert-manager"
  }
  labels = merge(var.common_labels, {
    "name" = "cert-manager"
    "team" = "platform-engineering"
    "cost-center" = "platform"
    "app.kubernetes.io/name" = "cert-manager"
  })

  depends_on = [time_sleep.wait_for_cert_manager]
}

resource "kubernetes_labels" "ingress_nginx_namespace" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "ingress-nginx"
  }
  labels = merge(var.common_labels, {
    "name" = "ingress-nginx"
    "team" = "platform-engineering"
    "cost-center" = "platform"
    "app.kubernetes.io/name" = "ingress-nginx"
  })

  depends_on = [helm_release.nginx_ingress]
}