output "otel_collector_endpoint" {
  description = "OpenTelemetry Collector endpoint for applications"
  value       = "http://otel-collector.${var.namespace}.svc.cluster.local:4318"
}

output "jaeger_query_endpoint" {
  description = "Jaeger Query UI endpoint"
  value       = var.environment == "local" ? "http://jaeger.localhost" : "https://jaeger.${var.environment}.ml-platform.dev"
}

output "tracing_config_map" {
  description = "Name of the tracing configuration ConfigMap"
  value       = kubernetes_config_map.tracing_config.metadata[0].name
}

output "auto_instrumentation_name" {
  description = "Name of the auto-instrumentation resource"
  value       = kubernetes_manifest.auto_instrumentation.manifest.metadata.name
}