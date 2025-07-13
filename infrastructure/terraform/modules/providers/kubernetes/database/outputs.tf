output "connection" {
  description = "Database connection details"
  value = {
    endpoint = "postgres.${var.name}.svc.cluster.local"
    port     = var.config.port
    username = var.config.username
    database = var.config.database_name
    url      = "postgresql://${var.config.username}@postgres.${var.name}.svc.cluster.local:${var.config.port}/${var.config.database_name}"
  }
  sensitive = true
}

output "credentials" {
  description = "Database credentials"
  value = {
    username             = var.config.username
    password_secret_name = "postgres-secret"
  }
  sensitive = true
}
