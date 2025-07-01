# ServiceMonitors for Automatic Service Discovery
# These allow teams to expose metrics by adding labels to their services

# ServiceMonitor for Database Services (PostgreSQL, Redis)
resource "kubernetes_manifest" "database_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "database-services"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "database-services"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["database", "cache", "postgresql", "redis"]
          }
        ]
      }

      namespaceSelector = {
        any = true
      }

      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# ServiceMonitor for Storage Services (MinIO, S3)
resource "kubernetes_manifest" "storage_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "storage-services"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "storage-services"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["storage", "minio", "object-storage"]
          }
        ]
      }

      namespaceSelector = {
        any = true
      }

      endpoints = [
        {
          port          = "metrics"
          path          = "/minio/v2/metrics/cluster"
          interval      = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# ServiceMonitor for ML Training Jobs
resource "kubernetes_manifest" "ml_training_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "ml-training-jobs"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "ml-training-jobs"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["ml-training", "ml-inference", "ml-workload"]
          }
        ]
      }

      namespaceSelector = {
        matchNames = var.ml_workload_namespaces
      }

      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "15s" # More frequent for training metrics
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# ServiceMonitor for Data Processing Jobs
resource "kubernetes_manifest" "data_processing_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "data-processing-jobs"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "data-processing-jobs"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["data-processing", "etl", "batch-job"]
          }
        ]
      }

      namespaceSelector = {
        matchNames = var.data_processing_namespaces
      }

      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# ServiceMonitor for Backend/API Services
resource "kubernetes_manifest" "backend_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "backend-services"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "backend-services"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["backend", "api", "web-service", "microservice"]
          }
        ]
      }

      namespaceSelector = {
        matchNames = var.application_namespaces
      }

      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
        },
        {
          port          = "health"
          path          = "/health/metrics"
          interval      = "60s"
          scrapeTimeout = "5s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# ServiceMonitor for Frontend Services
resource "kubernetes_manifest" "frontend_service_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "frontend-services"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "frontend-services"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["frontend", "ui", "web-app"]
          }
        ]
      }

      namespaceSelector = {
        matchNames = var.frontend_namespaces
      }

      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "60s" # Less frequent for frontend
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# PodMonitor for Jobs and CronJobs (since they don't have Services)
resource "kubernetes_manifest" "job_pod_monitor" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"

    metadata = {
      name      = "job-pods"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "job-pods"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
        matchExpressions = [
          {
            key      = "app.kubernetes.io/component"
            operator = "In"
            values   = ["job", "cronjob", "batch-job", "ml-training", "data-processing"]
          }
        ]
      }

      namespaceSelector = {
        any = true
      }

      podMetricsEndpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}