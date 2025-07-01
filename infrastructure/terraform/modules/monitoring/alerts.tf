# ML Platform Specific Alert Rules
# These alerts provide proactive monitoring for ML workloads

# PrometheusRule for ML Training Alerts
resource "kubernetes_manifest" "ml_training_alerts" {
  count = var.enable_prometheus && var.enable_alertmanager ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "ml-training-alerts"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "ml-training-alerts"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
        "role"                        = "alert-rules"
      }
    }

    spec = {
      groups = [
        {
          name     = "ml-training.rules"
          interval = "30s"
          rules = [
            {
              alert = "MLTrainingJobStuck"
              expr  = "kube_job_status_active{namespace=~\".*ml.*\",job_name=~\".*training.*\"} > 0 and on(job_name) kube_job_created{namespace=~\".*ml.*\"} < time() - 7200"
              for   = "15m"
              labels = {
                severity = "warning"
                service  = "ml-training"
                team     = "ml-platform"
              }
              annotations = {
                summary     = "ML Training Job Stuck"
                description = "ML Training job {{ $labels.job_name }} in namespace {{ $labels.namespace }} has been running for more than 2 hours without completion."
                runbook_url = "https://runbooks.company.com/ml-training-stuck"
              }
            },
            {
              alert = "MLTrainingJobFailed"
              expr  = "kube_job_status_failed{namespace=~\".*ml.*\",job_name=~\".*training.*\"} > 0"
              for   = "1m"
              labels = {
                severity = "critical"
                service  = "ml-training"
                team     = "ml-platform"
              }
              annotations = {
                summary     = "ML Training Job Failed"
                description = "ML Training job {{ $labels.job_name }} in namespace {{ $labels.namespace }} has failed."
                runbook_url = "https://runbooks.company.com/ml-training-failed"
              }
            },
            {
              alert = "MLTrainingLossNotDecreasing"
              expr  = "increase(training_loss{job=~\".*ml-training.*\"}[30m]) > 0"
              for   = "30m"
              labels = {
                severity = "warning"
                service  = "ml-training"
                team     = "ml-platform"
              }
              annotations = {
                summary     = "ML Training Loss Not Decreasing"
                description = "Training loss for job {{ $labels.job_name }} has not decreased in the last 30 minutes. Current loss: {{ $value }}"
                runbook_url = "https://runbooks.company.com/ml-training-loss"
              }
            },
            {
              alert = "MLTrainingLowAccuracy"
              expr  = "training_accuracy{job=~\".*ml-training.*\"} < 0.5"
              for   = "1h"
              labels = {
                severity = "warning"
                service  = "ml-training"
                team     = "ml-platform"
              }
              annotations = {
                summary     = "ML Training Low Accuracy"
                description = "Training accuracy for job {{ $labels.job_name }} is below 50% after 1 hour. Current accuracy: {{ $value }}"
                runbook_url = "https://runbooks.company.com/ml-training-accuracy"
              }
            },
            {
              alert = "MLTrainingGPUUtilizationLow"
              expr  = "avg(nvidia_gpu_utilization{namespace=~\".*ml.*\"}) < 30"
              for   = "15m"
              labels = {
                severity = "info"
                service  = "ml-training"
                team     = "ml-platform"
              }
              annotations = {
                summary     = "Low GPU Utilization"
                description = "Average GPU utilization is below 30% for the last 15 minutes. Current: {{ $value }}%"
                runbook_url = "https://runbooks.company.com/gpu-utilization"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# PrometheusRule for Data Processing Alerts
resource "kubernetes_manifest" "data_processing_alerts" {
  count = var.enable_prometheus && var.enable_alertmanager ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "data-processing-alerts"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "data-processing-alerts"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
        "role"                        = "alert-rules"
      }
    }

    spec = {
      groups = [
        {
          name     = "data-processing.rules"
          interval = "30s"
          rules = [
            {
              alert = "DataProcessingHighErrorRate"
              expr  = "rate(data_processing_errors_total{job=~\".*data.*\"}[5m]) / rate(data_records_processed_total{job=~\".*data.*\"}[5m]) > 0.05"
              for   = "10m"
              labels = {
                severity = "warning"
                service  = "data-processing"
                team     = "data-platform"
              }
              annotations = {
                summary     = "High Data Processing Error Rate"
                description = "Data processing error rate is above 5% for job {{ $labels.job_name }}. Current rate: {{ $value | humanizePercentage }}"
                runbook_url = "https://runbooks.company.com/data-processing-errors"
              }
            },
            {
              alert = "DataProcessingQueueBacklog"
              expr  = "data_queue_depth{job=~\".*data.*\"} > 10000"
              for   = "15m"
              labels = {
                severity = "warning"
                service  = "data-processing"
                team     = "data-platform"
              }
              annotations = {
                summary     = "Data Processing Queue Backlog"
                description = "Queue {{ $labels.queue_name }} has a backlog of {{ $value }} items for more than 15 minutes."
                runbook_url = "https://runbooks.company.com/data-queue-backlog"
              }
            },
            {
              alert = "DataProcessingLowThroughput"
              expr  = "rate(data_records_processed_total{job=~\".*data.*\"}[10m]) < 100"
              for   = "20m"
              labels = {
                severity = "info"
                service  = "data-processing"
                team     = "data-platform"
              }
              annotations = {
                summary     = "Low Data Processing Throughput"
                description = "Data processing throughput for {{ $labels.job_name }} is below 100 records/sec. Current: {{ $value | humanize }}/sec"
                runbook_url = "https://runbooks.company.com/data-processing-throughput"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# PrometheusRule for Infrastructure Alerts
resource "kubernetes_manifest" "infrastructure_alerts" {
  count = var.enable_prometheus && var.enable_alertmanager ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "infrastructure-alerts"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "infrastructure-alerts"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
        "role"                        = "alert-rules"
      }
    }

    spec = {
      groups = [
        {
          name     = "infrastructure.rules"
          interval = "30s"
          rules = [
            {
              alert = "MLPlatformDatabaseConnectionsHigh"
              expr  = "postgresql_connections_active{namespace=~\".*ml.*\"} / postgresql_connections_max{namespace=~\".*ml.*\"} > 0.8"
              for   = "5m"
              labels = {
                severity = "warning"
                service  = "database"
                team     = "platform"
              }
              annotations = {
                summary     = "High Database Connection Usage"
                description = "Database connection usage is above 80% in namespace {{ $labels.namespace }}. Current: {{ $value | humanizePercentage }}"
                runbook_url = "https://runbooks.company.com/database-connections"
              }
            },
            {
              alert = "MLPlatformDatabaseDown"
              expr  = "up{job=~\".*postgresql.*\",namespace=~\".*ml.*\"} == 0"
              for   = "2m"
              labels = {
                severity = "critical"
                service  = "database"
                team     = "platform"
              }
              annotations = {
                summary     = "ML Platform Database Down"
                description = "PostgreSQL database is down in namespace {{ $labels.namespace }}"
                runbook_url = "https://runbooks.company.com/database-down"
              }
            },
            {
              alert = "MLPlatformRedisDown"
              expr  = "up{job=~\".*redis.*\",namespace=~\".*ml.*\"} == 0"
              for   = "2m"
              labels = {
                severity = "critical"
                service  = "cache"
                team     = "platform"
              }
              annotations = {
                summary     = "ML Platform Redis Down"
                description = "Redis cache is down in namespace {{ $labels.namespace }}"
                runbook_url = "https://runbooks.company.com/redis-down"
              }
            },
            {
              alert = "MLPlatformStorageUsageHigh"
              expr  = "minio_cluster_usage_total_bytes / minio_cluster_capacity_total_bytes > 0.85"
              for   = "10m"
              labels = {
                severity = "warning"
                service  = "storage"
                team     = "platform"
              }
              annotations = {
                summary     = "High Storage Usage"
                description = "Storage usage is above 85%. Current: {{ $value | humanizePercentage }}"
                runbook_url = "https://runbooks.company.com/storage-usage"
              }
            },
            {
              alert = "MLPlatformPodCrashLooping"
              expr  = "rate(kube_pod_container_status_restarts_total{namespace=~\".*ml.*\"}[15m]) > 0"
              for   = "5m"
              labels = {
                severity = "warning"
                service  = "kubernetes"
                team     = "platform"
              }
              annotations = {
                summary     = "Pod Crash Looping"
                description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"
                runbook_url = "https://runbooks.company.com/pod-crash-loop"
              }
            },
            {
              alert = "MLPlatformHighMemoryUsage"
              expr  = "container_memory_working_set_bytes{namespace=~\".*ml.*\",container!=\"POD\"} / container_spec_memory_limit_bytes{namespace=~\".*ml.*\",container!=\"POD\"} > 0.9"
              for   = "10m"
              labels = {
                severity = "warning"
                service  = "kubernetes"
                team     = "platform"
              }
              annotations = {
                summary     = "High Memory Usage"
                description = "Container {{ $labels.container }} in pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of its memory limit"
                runbook_url = "https://runbooks.company.com/high-memory-usage"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}

# PrometheusRule for Custom ML Metrics Recording Rules
resource "kubernetes_manifest" "ml_recording_rules" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "ml-recording-rules"
      namespace = local.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "ml-recording-rules"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = var.namespace
        "prometheus"                  = "kube-prometheus"
        "role"                        = "recording-rules"
      }
    }

    spec = {
      groups = [
        {
          name     = "ml-platform.recording"
          interval = "30s"
          rules = [
            {
              record = "ml_platform:training_jobs_active"
              expr   = "sum(kube_job_status_active{namespace=~\".*ml.*\",job_name=~\".*training.*\"})"
            },
            {
              record = "ml_platform:training_jobs_completed_rate"
              expr   = "sum(rate(kube_job_status_completion_time{namespace=~\".*ml.*\",job_name=~\".*training.*\"}[1h]))"
            },
            {
              record = "ml_platform:data_processing_rate"
              expr   = "sum(rate(data_records_processed_total{job=~\".*data.*\"}[5m]))"
            },
            {
              record = "ml_platform:error_rate"
              expr   = "sum(rate(data_processing_errors_total{job=~\".*data.*\"}[5m])) / sum(rate(data_records_processed_total{job=~\".*data.*\"}[5m]))"
            },
            {
              record = "ml_platform:gpu_utilization_avg"
              expr   = "avg(nvidia_gpu_utilization{namespace=~\".*ml.*\"})"
            },
            {
              record = "ml_platform:resource_usage:cpu"
              expr   = "sum(rate(container_cpu_usage_seconds_total{namespace=~\".*ml.*\",container!=\"POD\"}[5m]))"
            },
            {
              record = "ml_platform:resource_usage:memory"
              expr   = "sum(container_memory_working_set_bytes{namespace=~\".*ml.*\",container!=\"POD\"})"
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.prometheus]
}