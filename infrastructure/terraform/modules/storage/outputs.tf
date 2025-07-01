# Local values removed - using is_local from main.tf

output "connection" {
  description = "Storage connection details"
  value = {
    endpoint   = local.is_local ? "http://minio.${var.namespace}.svc.cluster.local:9000" : "s3.${data.aws_region.current[0].name}.amazonaws.com"
    access_key = local.is_local ? "admin" : null
    region     = local.is_local ? null : data.aws_region.current[0].name
    buckets = { for bucket in var.config.buckets : bucket.name =>
    local.is_local ? bucket.name : "${var.name_prefix}-${bucket.name}" }
  }
  sensitive = true
}

output "credentials" {
  description = "Storage credentials (local environment only)"
  value = local.is_local ? {
    access_key = "admin"
    secret_key = random_password.minio_root_password[0].result
  } : null
  sensitive = true
}

output "s3_buckets" {
  description = "S3 bucket details (cloud environments only)"
  value = local.is_local ? null : {
    for bucket_name, bucket in aws_s3_bucket.buckets : bucket_name => {
      id                          = bucket.id
      arn                         = bucket.arn
      bucket_domain_name          = bucket.bucket_domain_name
      bucket_regional_domain_name = bucket.bucket_regional_domain_name
      hosted_zone_id              = bucket.hosted_zone_id
      region                      = bucket.region
    }
  }
}

output "kubernetes_resources" {
  description = "Kubernetes resource details (local environment only)"
  value = local.is_local ? {
    service_name = kubernetes_service.minio[0].metadata[0].name
    namespace    = var.namespace
    secret_name  = kubernetes_secret.minio_credentials[0].metadata[0].name
    pvc_name     = kubernetes_persistent_volume_claim.minio_data[0].metadata[0].name
  } : null
}

# Data source for AWS region (cloud environments only)
data "aws_region" "current" {
  count = local.is_local ? 0 : 1
}