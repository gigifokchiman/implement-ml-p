# AWS Secrets Manager Provider Variables

variable "name" {
  description = "Name for the secrets manager resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description             = string
    recovery_window_in_days = number
    secret_string           = optional(string)
    secret_binary           = optional(string)
    ignore_secret_changes   = optional(bool, true)
    enable_rotation         = optional(bool, false)
    rotation_days           = optional(number, 90)
    enable_replica          = optional(bool, false)
    replica_region          = optional(string)
    replica_kms_key_id      = optional(string)
    resource_policy         = optional(string)
  }))
  default = {}
}

variable "ignore_secret_changes" {
  description = "Ignore changes to secret values"
  type        = bool
  default     = true
}

variable "enable_rotation_lambda" {
  description = "Enable Lambda function for automatic rotation"
  type        = bool
  default     = false
}

variable "rotation_lambda_zip_path" {
  description = "Path to the Lambda function zip file"
  type        = string
  default     = null
}

variable "rotation_lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "rotation_lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.9"
}

variable "rotation_lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "rotation_lambda_env_vars" {
  description = "Environment variables for the rotation Lambda"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch logs retention period in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
