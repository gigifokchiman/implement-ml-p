# Platform Secret Store Outputs

output "provider_type" {
  description = "Type of secret store provider (aws or kubernetes)"
  value       = local.secret_store_info.provider_type
}

output "namespace" {
  description = "Kubernetes namespace (for Kubernetes provider)"
  value       = local.secret_store_info.namespace
}

output "secret_arns" {
  description = "ARNs of AWS secrets (for AWS provider)"
  value       = local.secret_store_info.secret_arns
}

output "secret_names" {
  description = "Names of secrets"
  value       = local.secret_store_info.secret_names
}

output "kms_key_id" {
  description = "KMS key ID for encryption (AWS only)"
  value       = local.secret_store_info.kms_key_id
}

output "service_account_name" {
  description = "Service account name for secret access (Kubernetes only)"
  value       = local.secret_store_info.service_account_name
}

output "access_method" {
  description = "Method for accessing secrets"
  value       = local.secret_store_info.access_method
}

# AWS-specific outputs
output "aws_secrets_manager_outputs" {
  description = "AWS Secrets Manager outputs"
  value = var.use_aws ? {
    secret_arns  = module.aws_secrets[0].secret_arns
    secret_names = module.aws_secrets[0].secret_names
    kms_key_id   = var.config.kms_key_id
  } : null
}

# Kubernetes-specific outputs
output "kubernetes_secrets_outputs" {
  description = "Kubernetes secrets outputs"
  value = var.use_aws ? null : {
    namespace            = module.kubernetes_secrets[0].namespace
    secret_names         = module.kubernetes_secrets[0].secret_names
    service_account_name = module.kubernetes_secrets[0].service_account_name
    config_map_name      = module.kubernetes_secrets[0].config_map_name
  }
}