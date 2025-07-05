# Platform Security Bootstrap Interface
# Provides unified interface for security infrastructure bootstrap

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
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Cert-Manager for TLS certificate management
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

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.8.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  # Configuration based on environment
  dynamic "set" {
    for_each = var.environment == "local" ? [1] : []
    content {
      name  = "controller.service.type"
      value = "NodePort"
    }
  }

  dynamic "set" {
    for_each = var.environment == "local" ? [1] : []
    content {
      name  = "controller.hostPort.enabled"
      value = "true"
    }
  }

  # Production configuration
  dynamic "set" {
    for_each = var.environment != "local" ? [1] : []
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

  wait          = true
  wait_for_jobs = true
}

# ClusterIssuer for Let's Encrypt (production clusters)
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.config.enable_cert_manager && var.environment != "local" ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "letsencrypt-prod"
      labels = var.tags
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
  count = var.config.enable_cert_manager ? 1 : 0
  depends_on      = [helm_release.cert_manager]
  create_duration = "120s"
}

# Self-signed issuer for local development
resource "kubernetes_manifest" "selfsigned_issuer" {
  count = var.config.enable_cert_manager && var.environment == "local" ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "selfsigned"
      labels = var.tags
    }
    spec = {
      selfSigned = {}
    }
  }

  depends_on = [time_sleep.wait_for_cert_manager]
}

# Pod Security Standards (if enabled)
resource "kubernetes_manifest" "pod_security_policy" {
  count = var.config.enable_pod_security ? 1 : 0

  manifest = {
    apiVersion = "policy/v1beta1"
    kind       = "PodSecurityPolicy"
    metadata = {
      name   = "${var.name}-${var.config.pod_security_standard}"
      labels = var.tags
    }
    spec = {
      privileged = var.config.pod_security_standard == "restricted" ? false : true
      allowPrivilegeEscalation = var.config.pod_security_standard == "restricted" ? false : true
      requiredDropCapabilities = var.config.pod_security_standard == "restricted" ? ["ALL"] : []
      volumes = var.config.pod_security_standard == "restricted" ? [
        "configMap",
        "emptyDir",
        "projected",
        "secret",
        "downwardAPI",
        "persistentVolumeClaim"
      ] : ["*"]
      runAsUser = {
        rule = var.config.pod_security_standard == "restricted" ? "MustRunAsNonRoot" : "RunAsAny"
      }
      seLinux = {
        rule = "RunAsAny"
      }
      fsGroup = {
        rule = "RunAsAny"
      }
    }
  }
}

# Network Policies for namespace isolation
resource "kubernetes_manifest" "default_network_policy" {
  count = var.config.enable_network_policies ? 1 : 0

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "default-deny-all"
      namespace = "default"
      labels    = var.tags
    }
    spec = {
      podSelector = {}
      policyTypes = ["Ingress", "Egress"]
    }
  }
}

# RBAC for security bootstrap
resource "kubernetes_cluster_role" "security_bootstrap" {
  count = var.config.enable_rbac ? 1 : 0

  metadata {
    name   = "${var.name}-security-bootstrap"
    labels = var.tags
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "services", "endpoints", "persistentvolumeclaims"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates", "issuers", "clusterissuers"]
    verbs      = ["get", "list", "watch"]
  }
}

# Namespace labeling for security policies
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

resource "kubernetes_labels" "ingress_nginx_namespace" {
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

# ArgoCD for GitOps (optional, environment-dependent)
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
    value = var.environment == "local" ? "ClusterIP" : "LoadBalancer"
  }

  set {
    name  = "server.insecure"
    value = var.environment == "local" ? "true" : "false"
  }

  set {
    name  = "configs.params.server.insecure"
    value = var.environment == "local" ? "true" : "false"
  }

  depends_on = [helm_release.cert_manager, helm_release.nginx_ingress]

  wait          = true
  wait_for_jobs = true
}

# Wait for ArgoCD CRDs to be established
resource "time_sleep" "wait_for_argocd" {
  count = var.config.enable_argocd ? 1 : 0
  
  create_duration = "60s"
  depends_on     = [helm_release.argocd]
}

# Output configuration
locals {
  security_bootstrap_info = {
    cert_manager_enabled  = var.config.enable_cert_manager
    ingress_class        = "nginx"
    cluster_issuer       = var.environment == "local" ? "selfsigned" : "letsencrypt-prod"
    pod_security_enabled = var.config.enable_pod_security
    network_policies_enabled = var.config.enable_network_policies
    rbac_enabled = var.config.enable_rbac
    argocd_enabled = var.config.enable_argocd
  }
}