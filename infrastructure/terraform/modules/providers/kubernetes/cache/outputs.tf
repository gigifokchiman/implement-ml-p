output "connection" {
  description = "Cache connection details"
  value = {
    endpoint = "${kubernetes_service.redis.metadata[0].name}.${kubernetes_namespace.cache.metadata[0].name}.svc.cluster.local"
    port     = 6379
    url      = "redis://${kubernetes_service.redis.metadata[0].name}.${kubernetes_namespace.cache.metadata[0].name}.svc.cluster.local:6379"
  }
  sensitive = true
}

output "credentials" {
  description = "Cache credentials"
  value = {
    # Redis without auth in local environment
    auth_required = false
  }
  sensitive = true
}