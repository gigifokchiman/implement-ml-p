# Local values removed - using is_local from main.tf

output "connection" {
  description = "Database connection details"
  value = {
    host     = local.is_local ? kubernetes_service.postgres[0].metadata[0].name : module.rds[0].db_instance_address
    port     = local.is_local ? 5432 : module.rds[0].db_instance_port
    database = var.config.database_name
    username = var.config.username
    url      = local.is_local ? "postgresql://${var.config.username}:${local.db_password}@${kubernetes_service.postgres[0].metadata[0].name}.${var.namespace}.svc.cluster.local:5432/${var.config.database_name}" : "postgresql://${var.config.username}:${local.db_password}@${module.rds[0].db_instance_address}:${module.rds[0].db_instance_port}/${var.config.database_name}"
  }
  sensitive = true
}

output "password" {
  description = "Database password"
  value       = local.db_password
  sensitive   = true
}

output "secret_arn" {
  description = "AWS Secrets Manager secret ARN (cloud environments only)"
  value       = local.is_local ? null : aws_secretsmanager_secret.db_password[0].arn
}

output "rds_instance" {
  description = "RDS instance details (cloud environments only)"
  value = local.is_local ? null : {
    id                = module.rds[0].db_instance_id
    arn               = module.rds[0].db_instance_arn
    endpoint          = module.rds[0].db_instance_endpoint
    hosted_zone_id    = module.rds[0].db_instance_hosted_zone_id
    resource_id       = module.rds[0].db_instance_resource_id
    status            = module.rds[0].db_instance_status
    security_group_id = try(module.rds[0].db_instance_security_group_id, null)
  }
}

output "kubernetes_resources" {
  description = "Kubernetes resource details (local environment only)"
  value = local.is_local ? {
    service_name = kubernetes_service.postgres[0].metadata[0].name
    namespace    = var.namespace
    secret_name  = kubernetes_secret.postgres_credentials[0].metadata[0].name
    pvc_name     = kubernetes_persistent_volume_claim.postgres_data[0].metadata[0].name
  } : null
}

# Local values removed - using db_password from main.tf