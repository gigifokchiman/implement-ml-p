output "connection" {
  description = "Storage connection details"
  value = {
    endpoint = "http://minio.${var.name}.svc.cluster.local:9000"
    buckets  = { for bucket in var.config.buckets : bucket.name => bucket.name }
  }
  sensitive = true
}

output "credentials" {
  description = "Storage credentials"
  value = {
    access_key             = "admin"
    secret_key_secret_name = "minio-secret"
  }
  sensitive = true
}