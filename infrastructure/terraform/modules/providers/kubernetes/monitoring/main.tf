# Kubernetes Prometheus/Grafana monitoring implementation

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

resource "random_password" "grafana_admin_password" {
  length  = 16
  special = false
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "monitoring"
      "app.kubernetes.io/component" = "monitoring"
      "team"                        = "platform-engineering"
      "cost-center"                 = "platform"
      "environment"                 = var.environment
      "workload-type"               = "monitoring"
    })
  }
}

# Metrics Server for resource metrics (CPU/Memory)
resource "helm_release" "metrics_server" {
  count = var.config.enable_metrics_server != false ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"

  # Increase timeout for deployment
  timeout = 600

  # Force update if exists
  force_update = true

  # Clean up on failure
  cleanup_on_fail = true

  values = [
    yamlencode({
      args = compact([
        "--cert-dir=/tmp",
        "--secure-port=4443",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s",
        # For local Kind clusters - disable TLS verification
        var.environment == "local" ? "--kubelet-insecure-tls" : "",
      ])

      # Override default container port
      containerPort = 4443

      resources = {
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
        limits = {
          cpu    = var.environment == "local" ? "200m" : "500m"
          memory = var.environment == "local" ? "300Mi" : "500Mi"
        }
      }

      # Remove securityContext that might be causing issues
      podSecurityContext = {
        runAsNonRoot = true
        runAsUser    = 1000
        fsGroup      = 1000
      }

      nodeSelector = {
        "kubernetes.io/os" = "linux"
      }

      priorityClassName = "system-cluster-critical"

      # API Service configuration
      apiService = {
        create                = true
        insecureSkipTLSVerify = var.environment == "local" ? true : false
      }

      # Add deployment configuration
      replicas = 1

      # Service configuration
      service = {
        type = "ClusterIP"
        port = 443
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
        }
      }

      # Add hostNetwork for Kind (disabled to avoid port conflicts)
      hostNetwork = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Prometheus using Helm
resource "helm_release" "prometheus" {
  count = var.config.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.config.prometheus_version
  namespace  = var.name

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
          password = random_password.grafana_admin_password.result
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
