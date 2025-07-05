# Platform Secret Store Variables

variable "name" {
  description = "Name of the secret store"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod, local)"
  type        = string
}

variable "use_aws" {
  description = "Whether to use AWS providers (true) or Kubernetes providers (false)"
  type        = bool
  default     = false
}

variable "config" {
  description = "Secret store configuration"
  type = object({
    enable_rotation   = optional(bool, false)
    rotation_days     = optional(number, 90)
    enable_encryption = optional(bool, true)
    kms_key_id        = optional(string, null)
  })
  default = {
    enable_rotation   = false
    rotation_days     = 90
    enable_encryption = true
    kms_key_id        = null
  }
}

# Platform secrets
variable "argocd_admin_password" {
  description = "ArgoCD admin password"
  type        = string
  sensitive   = true
  default     = "argocd-admin-password"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "grafana-admin-password"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
  default     = "postgres-admin-password"
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
  default     = "redis-password"
}

variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  sensitive   = true
  default     = "minio-access-key"
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  sensitive   = true
  default     = "minio-secret-key"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}