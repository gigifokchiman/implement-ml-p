# Local values removed - using is_local from main.tf

output "connection" {
  description = "Cache connection details"
  value = {
    host = local.is_local ? kubernetes_service.redis[0].metadata[0].name : module.elasticache[0].cluster_cache_nodes[0].address
    port = local.is_local ? 6379 : module.elasticache[0].cluster_cache_nodes[0].port
    url  = local.is_local ? "redis://:${random_password.redis_password[0].result}@${kubernetes_service.redis[0].metadata[0].name}.${var.namespace}.svc.cluster.local:6379" : var.config.encrypted ? "rediss://:${random_password.redis_auth[0].result}@${module.elasticache[0].cluster_cache_nodes[0].address}:${module.elasticache[0].cluster_cache_nodes[0].port}" : "redis://${module.elasticache[0].cluster_cache_nodes[0].address}:${module.elasticache[0].cluster_cache_nodes[0].port}"
  }
  sensitive = true
}

output "password" {
  description = "Cache password/auth token"
  value       = local.is_local ? random_password.redis_password[0].result : (var.config.encrypted ? random_password.redis_auth[0].result : null)
  sensitive   = true
}

output "elasticache_cluster" {
  description = "ElastiCache cluster details (cloud environments only)"
  value = local.is_local ? null : {
    id                     = module.elasticache[0].cluster_id
    arn                    = module.elasticache[0].cluster_arn
    cache_nodes            = module.elasticache[0].cluster_cache_nodes
    configuration_endpoint = try(module.elasticache[0].cluster_configuration_endpoint, null)
    security_group_id      = try(module.elasticache[0].security_group_id, null)
  }
}

output "kubernetes_resources" {
  description = "Kubernetes resource details (local environment only)"
  value = local.is_local ? {
    service_name = kubernetes_service.redis[0].metadata[0].name
    namespace    = var.namespace
    secret_name  = kubernetes_secret.redis_credentials[0].metadata[0].name
    pvc_name     = kubernetes_persistent_volume_claim.redis_data[0].metadata[0].name
  } : null
}