output "connection" {
  description = "Cache connection details"
  value = {
    endpoint = "redis.${var.name}.svc.cluster.local"
    port     = 6379
    url      = "redis://redis.${var.name}.svc.cluster.local:6379"
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