output "apm_endpoints" {
  description = "APM service endpoints"
  value = {
    jaeger_ui        = var.config.enable_distributed_trace ? "http://${kubernetes_service.jaeger[0].metadata[0].name}.${kubernetes_service.jaeger[0].metadata[0].namespace}.svc.cluster.local:16686" : null
    jaeger_collector = var.config.enable_distributed_trace ? "http://${kubernetes_service.jaeger[0].metadata[0].name}.${kubernetes_service.jaeger[0].metadata[0].namespace}.svc.cluster.local:14268" : null
    kibana           = var.config.enable_log_aggregation ? "http://${kubernetes_service.kibana[0].metadata[0].name}.${kubernetes_service.kibana[0].metadata[0].namespace}.svc.cluster.local:5601" : null
  }
}

output "tracing_endpoints" {
  description = "Distributed tracing endpoints"
  value = {
    otlp_grpc = var.config.enable_distributed_trace ? "http://${kubernetes_service.jaeger[0].metadata[0].name}.${kubernetes_service.jaeger[0].metadata[0].namespace}.svc.cluster.local:4317" : null
    otlp_http = var.config.enable_distributed_trace ? "http://${kubernetes_service.jaeger[0].metadata[0].name}.${kubernetes_service.jaeger[0].metadata[0].namespace}.svc.cluster.local:4318" : null
  }
}

output "metrics_endpoints" {
  description = "Custom metrics endpoints"
  value = {
    otel_collector_grpc = var.config.enable_custom_metrics ? "http://${kubernetes_service.otel_collector[0].metadata[0].name}.${kubernetes_service.otel_collector[0].metadata[0].namespace}.svc.cluster.local:4317" : null
    otel_collector_http = var.config.enable_custom_metrics ? "http://${kubernetes_service.otel_collector[0].metadata[0].name}.${kubernetes_service.otel_collector[0].metadata[0].namespace}.svc.cluster.local:4318" : null
    prometheus_metrics  = var.config.enable_custom_metrics ? "http://${kubernetes_service.otel_collector[0].metadata[0].name}.${kubernetes_service.otel_collector[0].metadata[0].namespace}.svc.cluster.local:8889/metrics" : null
  }
}

output "dashboards" {
  description = "Available performance monitoring dashboards"
  value = [
    var.config.enable_distributed_trace ? {
      name         = "Jaeger UI"
      url          = "http://localhost:16686"
      description  = "Distributed tracing visualization"
      port_forward = "kubectl port-forward -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} svc/jaeger 16686:16686"
    } : null,
    var.config.enable_log_aggregation ? {
      name         = "Kibana"
      url          = "http://localhost:5601"
      description  = "Log analysis and visualization"
      port_forward = "kubectl port-forward -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} svc/kibana 5601:5601"
    } : null,
    var.config.enable_custom_metrics ? {
      name         = "OpenTelemetry Metrics"
      url          = "http://localhost:8889/metrics"
      description  = "Custom application metrics"
      port_forward = "kubectl port-forward -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} svc/otel-collector 8889:8889"
    } : null
  ]
}

output "namespace" {
  description = "Performance monitoring namespace"
  value       = kubernetes_namespace.performance_monitoring.metadata[0].name
}

output "useful_commands" {
  description = "Useful commands for performance monitoring operations"
  value = [
    "# Port forward to Jaeger UI",
    var.config.enable_distributed_trace ? "kubectl port-forward -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} svc/jaeger 16686:16686" : null,
    "# Port forward to Kibana",
    var.config.enable_log_aggregation ? "kubectl port-forward -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} svc/kibana 5601:5601" : null,
    "# Port forward to OpenTelemetry Collector",
    var.config.enable_custom_metrics ? "kubectl port-forward -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} svc/otel-collector 4317:4317" : null,
    "# View OpenTelemetry Collector logs",
    var.config.enable_custom_metrics ? "kubectl logs -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} -l app.kubernetes.io/name=otel-collector" : null,
    "# Check Elasticsearch health",
    var.config.enable_log_aggregation ? "kubectl exec -n ${kubernetes_namespace.performance_monitoring.metadata[0].name} deployment/elasticsearch -- curl -s localhost:9200/_cluster/health" : null
  ]
}