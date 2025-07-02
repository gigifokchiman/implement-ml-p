# Kubernetes Prometheus/Grafana monitoring implementation

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "monitoring"
      "app.kubernetes.io/component" = "monitoring"
    })
  }
}

# Prometheus using Helm
resource "helm_release" "prometheus" {
  count = var.config.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.0.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      fullnameOverride = "prometheus"

      prometheus = {
        prometheusSpec = {
          retention = "${var.config.retention_days}d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.config.storage_size
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }
      }

      grafana = {
        enabled = var.config.enable_grafana
        admin = {
          user     = "admin"
          password = "admin123"
        }
        persistence = {
          enabled = true
          size    = "5Gi"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      alertmanager = {
        enabled = var.config.enable_alertmanager
        alertmanagerSpec = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }

      nodeExporter = {
        enabled = true
      }

      kubeStateMetrics = {
        enabled = true
      }

      commonLabels = merge(local.k8s_tags, {
        "app.kubernetes.io/managed-by" = "terraform"
      })
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}