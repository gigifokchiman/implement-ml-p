# Platform Secret Store Interface
# Provides unified interface for both AWS Secrets Manager and Kubernetes secrets


# AWS Secrets Manager Provider
module "aws_secrets" {
  count  = var.use_aws ? 1 : 0
  source = "../../providers/aws/secrets-manager"

  name        = var.name
  environment = var.environment

  # Configure secrets based on platform requirements
  secrets = {
    "platform-secrets" = {
      description             = "Platform secrets for ${var.name}"
      recovery_window_in_days = 7
      enable_rotation         = var.config.enable_rotation
      rotation_days           = var.config.rotation_days
      secret_string = jsonencode({
        argocd_admin_password   = var.argocd_admin_password
        grafana_admin_password  = var.grafana_admin_password
        postgres_admin_password = var.postgres_admin_password
        redis_password          = var.redis_password
        minio_access_key        = var.minio_access_key
        minio_secret_key        = var.minio_secret_key
      })
      ignore_secret_changes = true
      enable_replica        = var.environment == "prod"
      replica_region        = var.environment == "prod" ? "us-east-1" : null
      replica_kms_key_id    = var.environment == "prod" ? var.config.kms_key_id : null
      resource_policy       = null
    }
  }

  kms_key_id             = var.config.kms_key_id
  enable_rotation_lambda = var.config.enable_rotation

  # Lambda configuration for rotation
  rotation_lambda_zip_path = var.config.enable_rotation ? "${path.module}/rotation-lambda.zip" : null
  rotation_lambda_handler  = "index.handler"
  rotation_lambda_runtime  = "python3.9"
  rotation_lambda_timeout  = 300
  rotation_lambda_env_vars = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = var.environment == "prod" ? "INFO" : "DEBUG"
  }

  log_retention_days = var.environment == "prod" ? 30 : 7

  tags = var.tags
}

# Kubernetes Secrets Provider
module "kubernetes_secrets" {
  count  = var.use_aws ? 0 : 1
  source = "../../providers/kubernetes/secrets"

  name        = var.name
  environment = var.environment

  # Pass the secrets data
  argocd_admin_password   = var.argocd_admin_password
  grafana_admin_password  = var.grafana_admin_password
  postgres_admin_password = var.postgres_admin_password
  redis_password          = var.redis_password
  minio_access_key        = var.minio_access_key
  minio_secret_key        = var.minio_secret_key

  secret_store_namespace = "secret-store"

  tags = var.tags
}

# Output unified interface
locals {
  secret_store_info = var.use_aws ? {
    provider_type        = "aws"
    namespace            = null
    secret_arns          = module.aws_secrets[0].secret_arns
    secret_names         = module.aws_secrets[0].secret_names
    kms_key_id           = var.config.kms_key_id
    service_account_name = null
    access_method        = "aws-secrets-manager"
    } : {
    provider_type        = "kubernetes"
    namespace            = module.kubernetes_secrets[0].namespace
    secret_arns          = []
    secret_names         = module.kubernetes_secrets[0].secret_names
    kms_key_id           = null
    service_account_name = module.kubernetes_secrets[0].service_account_name
    access_method        = "kubernetes-secrets"
  }
}
