output "connection" {
  description = "Database connection details"
  value = {
    endpoint = "${kubernetes_service.postgres.metadata[0].name}.${kubernetes_namespace.database.metadata[0].name}.svc.cluster.local"
    port     = 5432
    username = var.config.username
    database = var.config.database_name
    url      = "postgresql://${var.config.username}@${kubernetes_service.postgres.metadata[0].name}.${kubernetes_namespace.database.metadata[0].name}.svc.cluster.local:5432/${var.config.database_name}"
  }
  sensitive = true
}

output "credentials" {
  description = "Database credentials"
  value = {
    username             = var.config.username
    password_secret_name = kubernetes_secret.postgres.metadata[0].name
  }
  sensitive = true
}