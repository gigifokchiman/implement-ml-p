output "connection" {
  description = "Storage connection details"
  value = {
    endpoint = "http://${kubernetes_service.minio.metadata[0].name}.${kubernetes_namespace.storage.metadata[0].name}.svc.cluster.local:9000"
    buckets  = { for bucket in var.config.buckets : bucket.name => bucket.name }
  }
  sensitive = true
}

output "credentials" {
  description = "Storage credentials"
  value = {
    access_key             = "admin"
    secret_key_secret_name = kubernetes_secret.minio.metadata[0].name
  }
  sensitive = true
}