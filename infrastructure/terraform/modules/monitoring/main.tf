# Monitoring module with Prometheus and Grafana
locals {
  name_prefix          = var.name_prefix
  monitoring_namespace = var.create_namespace ? kubernetes_namespace.monitoring[0].metadata[0].name : var.namespace
}

# Create monitoring namespace if requested
resource "kubernetes_namespace" "monitoring" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = "${var.namespace}-monitoring"
    labels = {
      name                          = "${var.namespace}-monitoring"
      "app.kubernetes.io/part-of"   = var.namespace
      "app.kubernetes.io/component" = "monitoring"
    }
  }
}

# Prometheus using official Helm chart
resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_chart_version
  namespace  = local.monitoring_namespace

  # Basic configuration
  values = [
    yamlencode({
      fullnameOverride = "prometheus"

      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention = var.metrics_retention
          storageSpec = var.enable_persistent_storage ? {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
                storageClassName = var.storage_class
              }
            }
          } : null

          # Resource limits
          resources = {
            requests = {
              cpu    = var.development_mode ? "100m" : "500m"
              memory = var.development_mode ? "512Mi" : "2Gi"
            }
            limits = {
              cpu    = var.development_mode ? "500m" : "2000m"
              memory = var.development_mode ? "1Gi" : "4Gi"
            }
          }

          # Security context
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }

          # Additional scrape configs for ML platform services
          additionalScrapeConfigs = [
            {
              job_name = "ml-platform-backend"
              kubernetes_sd_configs = [
                {
                  role = "pod"
                  namespaces = {
                    names = [var.namespace]
                  }
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
                  action        = "keep"
                  regex         = "backend|ml-platform-backend"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  action        = "keep"
                  regex         = "true"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                  action        = "replace"
                  target_label  = "__metrics_path__"
                  regex         = "(.+)"
                }
              ]
            },
            {
              job_name = "ml-training-jobs"
              kubernetes_sd_configs = [
                {
                  role = "pod"
                  namespaces = {
                    names = [var.namespace]
                  }
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_component"]
                  action        = "keep"
                  regex         = "ml-training|data-processing"
                }
              ]
            }
          ]
        }

        # Service configuration
        service = {
          type = var.expose_prometheus_ui ? "ClusterIP" : "ClusterIP"
        }
      }

      # Grafana configuration
      grafana = {
        enabled = var.enable_grafana

        admin = {
          user     = "admin"
          password = var.grafana_admin_password
        }

        # Persistence
        persistence = {
          enabled          = var.enable_persistent_storage
          size             = var.grafana_storage_size
          storageClassName = var.storage_class
        }

        # Resources
        resources = {
          requests = {
            cpu    = var.development_mode ? "50m" : "100m"
            memory = var.development_mode ? "128Mi" : "256Mi"
          }
          limits = {
            cpu    = var.development_mode ? "200m" : "500m"
            memory = var.development_mode ? "256Mi" : "512Mi"
          }
        }

        # Security context
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 472
          fsGroup      = 472
        }

        # Pre-configured dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "ml-platform-dashboards"
                orgId           = 1
                folder          = "ML Platform"
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/ml-platform"
                }
              }
            ]
          }
        }

        dashboards = {
          "ml-platform-dashboards" = {
            "ml-platform-overview" = {
              gnetId     = 315 # Node Exporter Full
              revision   = 3
              datasource = "Prometheus"
            }
            "kubernetes-cluster" = {
              gnetId     = 7249 # Kubernetes Cluster
              revision   = 1
              datasource = "Prometheus"
            }
          }
        }

        # Service configuration
        service = {
          type = var.expose_grafana_ui ? "ClusterIP" : "ClusterIP"
        }
      }

      # Alert Manager configuration
      alertmanager = {
        enabled = var.enable_alertmanager

        alertmanagerSpec = {
          # Storage
          storage = var.enable_persistent_storage ? {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
                storageClassName = var.storage_class
              }
            }
          } : null

          # Resources
          resources = {
            requests = {
              cpu    = var.development_mode ? "50m" : "100m"
              memory = var.development_mode ? "64Mi" : "128Mi"
            }
            limits = {
              cpu    = var.development_mode ? "200m" : "500m"
              memory = var.development_mode ? "128Mi" : "256Mi"
            }
          }

          # Security context
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }
        }
      }

      # Node Exporter
      nodeExporter = {
        enabled = var.enable_node_exporter
      }

      # kube-state-metrics
      kubeStateMetrics = {
        enabled = true
      }

      # Common labels
      commonLabels = {
        "app.kubernetes.io/part-of"    = var.namespace
        "app.kubernetes.io/managed-by" = "terraform"
        environment                    = var.environment
      }
    })
  ]

  # Wait for namespace to be created
  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

# ServiceMonitor for ML Platform services
resource "kubernetes_manifest" "ml_platform_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "ml-platform-services"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "ml-platform-services"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/part-of" = var.namespace
        }
      }

      namespaceSelector = {
        matchNames = [var.namespace]
      }

      endpoints = [
        {
          port     = "metrics"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# PrometheusRule for ML Platform alerts
resource "kubernetes_manifest" "ml_platform_alerts" {
  count = var.enable_prometheus && var.enable_alertmanager ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "ml-platform-alerts"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "ml-platform-alerts"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        prometheus                    = "kube-prometheus"
        role                          = "alert-rules"
      }
    }

    spec = {
      groups = [
        {
          name = "ml-platform.rules"
          rules = [
            {
              alert = "MLPlatformBackendDown"
              expr  = "up{job=\"ml-platform-backend\"} == 0"
              for   = "5m"
              labels = {
                severity = "critical"
                service  = "backend"
              }
              annotations = {
                summary     = "ML Platform Backend is down"
                description = "ML Platform Backend has been down for more than 5 minutes."
              }
            },
            {
              alert = "MLTrainingJobFailed"
              expr  = "kube_job_status_failed{namespace=\"${var.namespace}\",job_name=~\".*ml-training.*\"} > 0"
              for   = "1m"
              labels = {
                severity = "warning"
                service  = "ml-training"
              }
              annotations = {
                summary     = "ML Training Job Failed"
                description = "ML Training job {{ $labels.job_name }} has failed."
              }
            },
            {
              alert = "DataProcessingJobStuck"
              expr  = "kube_job_status_active{namespace=\"${var.namespace}\",job_name=~\".*data-processing.*\"} > 0 and on(job_name) kube_job_created{namespace=\"${var.namespace}\"} < time() - 3600"
              for   = "10m"
              labels = {
                severity = "warning"
                service  = "data-processing"
              }
              annotations = {
                summary     = "Data Processing Job Stuck"
                description = "Data processing job {{ $labels.job_name }} has been running for more than 1 hour."
              }
            },
            {
              alert = "MLPlatformDatabaseConnections"
              expr  = "postgresql_connections_active{namespace=\"${var.namespace}\"} / postgresql_connections_max{namespace=\"${var.namespace}\"} > 0.8"
              for   = "5m"
              labels = {
                severity = "warning"
                service  = "database"
              }
              annotations = {
                summary     = "High Database Connection Usage"
                description = "Database connection usage is above 80%."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# Grafana Ingress (if requested)
resource "kubernetes_ingress_v1" "grafana" {
  count = var.enable_grafana && var.expose_grafana_ui ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = local.monitoring_namespace
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.grafana_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "${helm_release.prometheus[0].name}-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.prometheus]
}
# Jaeger for distributed tracing (if enabled)
resource "helm_release" "jaeger" {
  count = var.enable_jaeger ? 1 : 0

  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  version    = var.jaeger_chart_version
  namespace  = local.monitoring_namespace

  values = [
    yamlencode({
      provisionDataStore = {
        cassandra     = false
        elasticsearch = var.environment != "local"
        kafka         = false
      }

      storage = var.environment == "local" ? {
        type = "memory"
        } : {
        type = "elasticsearch"
        elasticsearch = {
          host     = "elasticsearch.${local.monitoring_namespace}.svc.cluster.local"
          port     = 9200
          scheme   = "http"
          user     = ""
          password = ""
        }
      }

      agent = {
        enabled = true
        daemonset = {
          useHostPort = true
        }
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "256m"
            memory = "128Mi"
          }
        }
      }

      collector = {
        enabled      = true
        replicaCount = var.environment == "local" ? 1 : 2
        resources = {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      query = {
        enabled      = true
        replicaCount = var.environment == "local" ? 1 : 2
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "256m"
            memory = "256Mi"
          }
        }
        ingress = {
          enabled   = var.enable_ingress
          className = "nginx"
          hosts = [{
            host = "jaeger.${var.environment}.ml-platform.dev"
            paths = [{
              path     = "/"
              pathType = "Prefix"
            }]
          }]
        }
      }

      elasticsearch = var.environment != "local" ? {
        enabled  = true
        replicas = 1
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      } : null
    })
  ]

  depends_on = [helm_release.prometheus]
}

# OpenTelemetry Operator for auto-instrumentation
resource "helm_release" "opentelemetry_operator" {
  count = var.enable_opentelemetry ? 1 : 0

  name       = "opentelemetry-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  version    = "0.47.1"
  namespace  = local.monitoring_namespace

  values = [
    yamlencode({
      manager = {
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "64Mi"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.prometheus]
}