output "prometheus_url" {
  description = "Prometheus service URL"
  value       = var.enable_prometheus ? "http://${helm_release.prometheus[0].name}-prometheus.${local.monitoring_namespace}.svc.cluster.local:9090" : null
}

output "grafana_url" {
  description = "Grafana service URL"
  value       = var.enable_grafana ? "http://${helm_release.prometheus[0].name}-grafana.${local.monitoring_namespace}.svc.cluster.local" : null
}

output "grafana_external_url" {
  description = "Grafana external URL (if ingress is enabled)"
  value       = var.enable_grafana && var.expose_grafana_ui ? "http://${var.grafana_hostname}" : null
}

output "alertmanager_url" {
  description = "AlertManager service URL"
  value       = var.enable_alertmanager ? "http://${helm_release.prometheus[0].name}-alertmanager.${local.monitoring_namespace}.svc.cluster.local:9093" : null
}

output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = local.monitoring_namespace
}

output "prometheus_service_monitor" {
  description = "ServiceMonitor name for ML Platform services"
  value       = var.enable_prometheus ? kubernetes_manifest.ml_platform_service_monitor[0].manifest.metadata.name : null
}

output "helm_release_name" {
  description = "Prometheus Helm release name"
  value       = var.enable_prometheus ? helm_release.prometheus[0].name : null
}

output "monitoring_endpoints" {
  description = "All monitoring service endpoints"
  value = {
    prometheus = var.enable_prometheus ? {
      internal_url = "http://${helm_release.prometheus[0].name}-prometheus.${local.monitoring_namespace}.svc.cluster.local:9090"
      port         = 9090
    } : null

    grafana = var.enable_grafana ? {
      internal_url = "http://${helm_release.prometheus[0].name}-grafana.${local.monitoring_namespace}.svc.cluster.local"
      external_url = var.expose_grafana_ui ? "http://${var.grafana_hostname}" : null
      port         = 80
      admin_user   = "admin"
    } : null

    alertmanager = var.enable_alertmanager ? {
      internal_url = "http://${helm_release.prometheus[0].name}-alertmanager.${local.monitoring_namespace}.svc.cluster.local:9093"
      port         = 9093
    } : null
  }
  sensitive = true
}

output "service_discovery_guide" {
  description = "Guide for teams to enable monitoring on their services"
  value = {
    for_services = {
      labels_required = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "metrics-port-number"
        "prometheus.io/path"   = "/metrics (optional, defaults to /metrics)"
      }
      example_service = {
        apiVersion = "v1"
        kind       = "Service"
        metadata = {
          name = "my-ml-service"
          labels = {
            "app.kubernetes.io/component" = "ml-training" # or ml-inference, data-processing, backend, etc.
            "prometheus.io/scrape"        = "true"
            "prometheus.io/port"          = "9090"
            "prometheus.io/path"          = "/metrics"
          }
        }
        spec = {
          ports = [
            { name = "metrics", port = 9090, targetPort = 9090 }
          ]
        }
      }
    }

    for_pods = {
      labels_required = {
        "prometheus.io/scrape"        = "true"
        "app.kubernetes.io/component" = "job, cronjob, ml-training, data-processing, etc."
      }
      example_job = {
        apiVersion = "batch/v1"
        kind       = "Job"
        metadata = {
          name = "ml-training-job"
        }
        spec = {
          template = {
            metadata = {
              labels = {
                "app.kubernetes.io/component" = "ml-training"
                "prometheus.io/scrape"        = "true"
              }
            }
            spec = {
              containers = [
                {
                  name = "trainer"
                  ports = [
                    { name = "metrics", containerPort = 9090 }
                  ]
                }
              ]
            }
          }
        }
      }
    }

    available_service_monitors = {
      database_services    = "Monitors: postgresql, redis, cache"
      storage_services     = "Monitors: minio, object-storage"
      ml_training_jobs     = "Monitors: ml-training, ml-inference, ml-workload"
      data_processing_jobs = "Monitors: data-processing, etl, batch-job"
      backend_services     = "Monitors: backend, api, web-service, microservice"
      frontend_services    = "Monitors: frontend, ui, web-app"
      job_pods             = "Monitors: job, cronjob, batch-job pods"
    }

    custom_metrics_examples = {
      ml_training = [
        "training_loss",
        "training_accuracy",
        "training_epochs_completed",
        "training_samples_processed_total"
      ]
      data_processing = [
        "data_records_processed_total",
        "data_processing_errors_total",
        "data_queue_depth"
      ]
      application = [
        "http_requests_total",
        "http_request_duration_seconds",
        "application_errors_total"
      ]
    }
  }
}

output "useful_commands" {
  description = "Useful commands for monitoring"
  value = {
    port_forward_grafana      = "kubectl port-forward -n ${local.monitoring_namespace} svc/${var.enable_prometheus ? helm_release.prometheus[0].name : "prometheus"}-grafana 3000:80"
    port_forward_prometheus   = "kubectl port-forward -n ${local.monitoring_namespace} svc/${var.enable_prometheus ? helm_release.prometheus[0].name : "prometheus"}-prometheus 9090:9090"
    port_forward_alertmanager = "kubectl port-forward -n ${local.monitoring_namespace} svc/${var.enable_prometheus ? helm_release.prometheus[0].name : "prometheus"}-alertmanager 9093:9093"

    view_servicemonitors = "kubectl get servicemonitors -n ${local.monitoring_namespace}"
    view_prometheusrules = "kubectl get prometheusrules -n ${local.monitoring_namespace}"
    view_dashboards      = "kubectl get configmaps -n ${local.monitoring_namespace} -l grafana_dashboard=1"

    check_targets = "Open Prometheus -> Status -> Targets"
    check_rules   = "Open Prometheus -> Status -> Rules"
    grafana_login = "Username: admin, Password: ${var.grafana_admin_password}"
  }
}

# Local values removed - using monitoring_namespace from main.tf