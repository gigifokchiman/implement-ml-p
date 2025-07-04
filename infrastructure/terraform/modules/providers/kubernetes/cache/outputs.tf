output "connection" {
  description = "Cache connection details"
  value = {
    endpoint = "redis.${var.name}.svc.cluster.local"
    port     = var.config.port
    url      = "redis://redis.${var.name}.svc.cluster.local:${var.config.port}"
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