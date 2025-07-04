# Security Bootstrap Module
# Deploys cert-manager, NGINX ingress, ArgoCD, and Prometheus Operator

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Generate random password for ArgoCD if not provided
resource "random_password" "argocd_admin" {
  length  = 16
  special = true
}

# 1. cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_config.version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  values = [
    yamlencode({
      podLabels = var.tags
      resources = {
        requests = {
          cpu    = "10m"
          memory = "32Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]
}

# 2. NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.8.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        podLabels = var.tags
        service = {
          type = var.environment == "local" ? "NodePort" : "LoadBalancer"
        }
        nodeSelector = var.environment == "local" ? {
          "ingress-ready" = "true"
        } : {}
        tolerations = var.environment == "local" ? [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "Equal"
            effect   = "NoSchedule"
          },
          {
            key      = "node-role.kubernetes.io/master"
            operator = "Equal"
            effect   = "NoSchedule"
          }
        ] : []
        resources = {
          requests = {
            cpu    = "100m"
            memory = "90Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        admissionWebhooks = {
          enabled = var.environment == "local" ? false : true
          failurePolicy = "Ignore"
        }
      }
    })
  ]

  depends_on = [helm_release.cert_manager]
}

# Wait for cert-manager CRDs to be established
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# 3. ClusterIssuers for cert-manager
resource "kubernetes_manifest" "selfsigned_issuer" {
  count = var.cert_manager_config.enable_cluster_issuer ? 1 : 0

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

resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.cert_manager_config.enable_cluster_issuer && var.environment != "local" ? 1 : 0

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
        email  = var.cert_manager_config.letsencrypt_email
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

# 4. ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_config.version
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        podLabels = var.tags
      }
      configs = {
        params = {
          "server.insecure" = var.argocd_config.enable_tls ? "false" : "true"
        }
        secret = {
          argocdServerAdminPassword = bcrypt(var.argocd_config.admin_password != "" ? var.argocd_config.admin_password : random_password.argocd_admin.result)
        }
      }
      server = {
        service = {
          type = var.environment == "local" ? "NodePort" : "ClusterIP"
        }
        ingress = {
          enabled          = var.environment != "local"
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer"               = var.environment == "local" ? "selfsigned" : "letsencrypt-prod"
            "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
            "nginx.ingress.kubernetes.io/backend-protocol" = "GRPC"
          }
          hosts = var.environment != "local" ? [
            {
              host = "argocd.${var.cluster_name}.example.com"
              paths = [
                {
                  path     = "/"
                  pathType = "Prefix"
                }
              ]
            }
          ] : []
          tls = var.environment != "local" ? [
            {
              secretName = "argocd-server-tls"
              hosts      = ["argocd.${var.cluster_name}.example.com"]
            }
          ] : []
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      controller = {
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }
      repoServer = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.nginx_ingress, kubernetes_manifest.selfsigned_issuer]
}

# Wait for ArgoCD CRDs to be established
resource "time_sleep" "wait_for_argocd" {
  depends_on      = [helm_release.argocd]
  create_duration = "60s"
}

# 5. Prometheus Operator (kube-prometheus-stack)
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_config.version
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        podLabels = var.tags
      }
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues           = false
          retention                               = var.prometheus_config.retention_days
          storageSpec = var.prometheus_config.storage_class != "" ? {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.prometheus_config.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          } : null
          resources = {
            requests = {
              cpu    = "200m"
              memory = "400Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
        }
        service = {
          type = var.environment == "local" ? "NodePort" : "ClusterIP"
        }
      }
      grafana = {
        enabled       = var.prometheus_config.enable_grafana
        adminPassword = var.prometheus_config.grafana_admin_password
        service = {
          type = var.environment == "local" ? "NodePort" : "ClusterIP"
        }
        ingress = {
          enabled          = var.environment != "local" && var.prometheus_config.enable_grafana
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer"           = var.environment == "local" ? "selfsigned" : "letsencrypt-prod"
            "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
          }
          hosts = var.environment != "local" ? [
            {
              host = "grafana.${var.cluster_name}.example.com"
              paths = [
                {
                  path     = "/"
                  pathType = "Prefix"
                }
              ]
            }
          ] : []
          tls = var.environment != "local" ? [
            {
              secretName = "grafana-tls"
              hosts      = ["grafana.${var.cluster_name}.example.com"]
            }
          ] : []
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.nginx_ingress]
}

# Add compliance labels to Helm-created namespaces
resource "kubernetes_labels" "argocd_namespace" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "argocd"
  }
  labels = merge(var.tags, {
    "team"          = "platform-engineering"
    "cost-center"   = "platform"
    "environment"   = var.environment
    "workload-type" = "gitops"
  })

  depends_on = [helm_release.argocd]
}

resource "kubernetes_labels" "monitoring_namespace" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "monitoring"
  }
  labels = merge(var.tags, {
    "team"          = "platform-engineering"
    "cost-center"   = "platform"
    "environment"   = var.environment
    "workload-type" = "observability"
  })

  depends_on = [helm_release.prometheus]
}