# ML Platform Specific Grafana Dashboards
# These dashboards provide ML-specific monitoring and observability

# ConfigMap for ML Platform Overview Dashboard
resource "kubernetes_config_map" "ml_platform_overview_dashboard" {
  count = var.enable_grafana ? 1 : 0

  metadata {
    name      = "ml-platform-overview-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      "grafana_dashboard"           = "1"
      "app.kubernetes.io/name"      = "ml-platform-overview"
      "app.kubernetes.io/component" = "dashboard"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  data = {
    "ml-platform-overview.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "ML Platform Overview"
        tags     = ["ml-platform", "overview"]
        style    = "dark"
        timezone = "browser"
        refresh  = "30s"
        time = {
          from = "now-1h"
          to   = "now"
        }

        panels = [
          {
            id      = 1
            title   = "Platform Health Status"
            type    = "stat"
            gridPos = { h = 8, w = 12, x = 0, y = 0 }
            targets = [
              {
                expr         = "up{job=~\".*ml-platform.*\"}"
                legendFormat = "{{job}}"
                refId        = "A"
              }
            ]
            fieldConfig = {
              defaults = {
                color = {
                  mode = "thresholds"
                }
                thresholds = {
                  steps = [
                    { color = "red", value = 0 },
                    { color = "green", value = 1 }
                  ]
                }
                mappings = [
                  { type = "value", value = "0", text = "Down" },
                  { type = "value", value = "1", text = "Up" }
                ]
              }
            }
          },
          {
            id      = 2
            title   = "Active ML Training Jobs"
            type    = "stat"
            gridPos = { h = 8, w = 12, x = 12, y = 0 }
            targets = [
              {
                expr         = "sum(kube_job_status_active{namespace=~\".*ml.*\",job_name=~\".*training.*\"})"
                legendFormat = "Active Jobs"
                refId        = "A"
              }
            ]
          },
          {
            id      = 3
            title   = "CPU Usage by Service"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 8 }
            targets = [
              {
                expr         = "rate(container_cpu_usage_seconds_total{namespace=~\".*ml.*\",container!=\"POD\"}[5m])"
                legendFormat = "{{namespace}}/{{pod}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 4
            title   = "Memory Usage by Service"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 16 }
            targets = [
              {
                expr         = "container_memory_working_set_bytes{namespace=~\".*ml.*\",container!=\"POD\"}"
                legendFormat = "{{namespace}}/{{pod}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 5
            title   = "Database Connections"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 0, y = 24 }
            targets = [
              {
                expr         = "postgresql_connections_active"
                legendFormat = "Active Connections"
                refId        = "A"
              },
              {
                expr         = "postgresql_connections_max"
                legendFormat = "Max Connections"
                refId        = "B"
              }
            ]
          },
          {
            id      = 6
            title   = "Storage Usage"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 12, y = 24 }
            targets = [
              {
                expr         = "minio_cluster_usage_total_bytes"
                legendFormat = "Total Storage Used"
                refId        = "A"
              }
            ]
          }
        ]
      }
    })
  }
}

# ConfigMap for ML Training Dashboard
resource "kubernetes_config_map" "ml_training_dashboard" {
  count = var.enable_grafana ? 1 : 0

  metadata {
    name      = "ml-training-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      "grafana_dashboard"           = "1"
      "app.kubernetes.io/name"      = "ml-training"
      "app.kubernetes.io/component" = "dashboard"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  data = {
    "ml-training.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "ML Training Jobs"
        tags     = ["ml-platform", "training", "ml"]
        style    = "dark"
        timezone = "browser"
        refresh  = "10s"
        time = {
          from = "now-1h"
          to   = "now"
        }

        panels = [
          {
            id      = 1
            title   = "Training Job Status"
            type    = "stat"
            gridPos = { h = 8, w = 8, x = 0, y = 0 }
            targets = [
              {
                expr         = "sum(kube_job_status_active{job_name=~\".*training.*\"})"
                legendFormat = "Active"
                refId        = "A"
              },
              {
                expr         = "sum(kube_job_status_succeeded{job_name=~\".*training.*\"})"
                legendFormat = "Succeeded"
                refId        = "B"
              },
              {
                expr         = "sum(kube_job_status_failed{job_name=~\".*training.*\"})"
                legendFormat = "Failed"
                refId        = "C"
              }
            ]
          },
          {
            id      = 2
            title   = "Training Loss (Custom Metric)"
            type    = "timeseries"
            gridPos = { h = 8, w = 16, x = 8, y = 0 }
            targets = [
              {
                expr         = "training_loss{job=~\".*ml-training.*\"}"
                legendFormat = "Loss - {{job_name}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 3
            title   = "Training Accuracy (Custom Metric)"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 0, y = 8 }
            targets = [
              {
                expr         = "training_accuracy{job=~\".*ml-training.*\"}"
                legendFormat = "Accuracy - {{job_name}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 4
            title   = "Epochs Completed"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 12, y = 8 }
            targets = [
              {
                expr         = "training_epochs_completed{job=~\".*ml-training.*\"}"
                legendFormat = "Epochs - {{job_name}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 5
            title   = "GPU Utilization"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 16 }
            targets = [
              {
                expr         = "nvidia_gpu_utilization{namespace=~\".*ml.*\"}"
                legendFormat = "GPU {{gpu}} - {{pod}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 6
            title   = "Data Processing Rate"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 24 }
            targets = [
              {
                expr         = "rate(training_samples_processed_total{job=~\".*ml-training.*\"}[5m])"
                legendFormat = "Samples/sec - {{job_name}}"
                refId        = "A"
              }
            ]
          }
        ]
      }
    })
  }
}

# ConfigMap for Data Processing Dashboard
resource "kubernetes_config_map" "data_processing_dashboard" {
  count = var.enable_grafana ? 1 : 0

  metadata {
    name      = "data-processing-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      "grafana_dashboard"           = "1"
      "app.kubernetes.io/name"      = "data-processing"
      "app.kubernetes.io/component" = "dashboard"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  data = {
    "data-processing.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Data Processing Pipelines"
        tags     = ["ml-platform", "data", "etl"]
        style    = "dark"
        timezone = "browser"
        refresh  = "30s"
        time = {
          from = "now-4h"
          to   = "now"
        }

        panels = [
          {
            id      = 1
            title   = "Pipeline Status"
            type    = "stat"
            gridPos = { h = 8, w = 12, x = 0, y = 0 }
            targets = [
              {
                expr         = "sum(kube_job_status_active{job_name=~\".*data.*|.*etl.*\"})"
                legendFormat = "Active Pipelines"
                refId        = "A"
              }
            ]
          },
          {
            id      = 2
            title   = "Records Processed"
            type    = "stat"
            gridPos = { h = 8, w = 12, x = 12, y = 0 }
            targets = [
              {
                expr         = "sum(increase(data_records_processed_total[1h]))"
                legendFormat = "Records/hour"
                refId        = "A"
              }
            ]
          },
          {
            id      = 3
            title   = "Processing Rate"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 8 }
            targets = [
              {
                expr         = "rate(data_records_processed_total{job=~\".*data.*\"}[5m])"
                legendFormat = "{{job_name}} - Records/sec"
                refId        = "A"
              }
            ]
          },
          {
            id      = 4
            title   = "Error Rate"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 0, y = 16 }
            targets = [
              {
                expr         = "rate(data_processing_errors_total{job=~\".*data.*\"}[5m])"
                legendFormat = "{{job_name}} - Errors/sec"
                refId        = "A"
              }
            ]
          },
          {
            id      = 5
            title   = "Queue Depth"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 12, y = 16 }
            targets = [
              {
                expr         = "data_queue_depth{job=~\".*data.*\"}"
                legendFormat = "{{queue_name}}"
                refId        = "A"
              }
            ]
          }
        ]
      }
    })
  }
}

# ConfigMap for Infrastructure Dashboard
resource "kubernetes_config_map" "infrastructure_dashboard" {
  count = var.enable_grafana ? 1 : 0

  metadata {
    name      = "infrastructure-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      "grafana_dashboard"           = "1"
      "app.kubernetes.io/name"      = "infrastructure"
      "app.kubernetes.io/component" = "dashboard"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  data = {
    "infrastructure.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Infrastructure Overview"
        tags     = ["infrastructure", "kubernetes", "ml-platform"]
        style    = "dark"
        timezone = "browser"
        refresh  = "30s"
        time = {
          from = "now-1h"
          to   = "now"
        }

        panels = [
          {
            id      = 1
            title   = "Cluster Resource Usage"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 0 }
            targets = [
              {
                expr         = "sum(rate(container_cpu_usage_seconds_total{container!=\"POD\"}[5m])) by (node)"
                legendFormat = "CPU - {{node}}"
                refId        = "A"
              },
              {
                expr         = "sum(container_memory_working_set_bytes{container!=\"POD\"}) by (node) / 1024/1024/1024"
                legendFormat = "Memory GB - {{node}}"
                refId        = "B"
              }
            ]
          },
          {
            id      = 2
            title   = "Pod Distribution"
            type    = "piechart"
            gridPos = { h = 8, w = 12, x = 0, y = 8 }
            targets = [
              {
                expr         = "sum(kube_pod_info) by (namespace)"
                legendFormat = "{{namespace}}"
                refId        = "A"
              }
            ]
          },
          {
            id      = 3
            title   = "Storage Usage"
            type    = "timeseries"
            gridPos = { h = 8, w = 12, x = 12, y = 8 }
            targets = [
              {
                expr         = "kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100"
                legendFormat = "{{persistentvolumeclaim}} - Usage %"
                refId        = "A"
              }
            ]
          },
          {
            id      = 4
            title   = "Network I/O"
            type    = "timeseries"
            gridPos = { h = 8, w = 24, x = 0, y = 16 }
            targets = [
              {
                expr         = "rate(container_network_receive_bytes_total{interface=\"eth0\"}[5m])"
                legendFormat = "RX - {{pod}}"
                refId        = "A"
              },
              {
                expr         = "rate(container_network_transmit_bytes_total{interface=\"eth0\"}[5m])"
                legendFormat = "TX - {{pod}}"
                refId        = "B"
              }
            ]
          }
        ]
      }
    })
  }
}