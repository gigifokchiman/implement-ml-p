output "endpoints" {
  description = "Monitoring endpoints"
  value = {
    prometheus   = var.config.enable_prometheus ? "http://prometheus-server.monitoring.svc.cluster.local:9090" : null
    grafana      = var.config.enable_grafana ? "http://prometheus-grafana.monitoring.svc.cluster.local:80" : null
    alertmanager = var.config.enable_alertmanager ? "http://prometheus-alertmanager.monitoring.svc.cluster.local:9093" : null
  }
  sensitive = true
}

output "dashboards" {
  description = "Available dashboards"
  value = {
    kubernetes_cluster = "Kubernetes Cluster Overview"
    node_exporter      = "Node Exporter Dashboard"
    prometheus_stats   = "Prometheus Stats"
  }
}