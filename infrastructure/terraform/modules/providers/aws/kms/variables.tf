# AWS KMS Provider Variables

variable "name" {
  description = "Name for the KMS key"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "description" {
  description = "Description for the KMS key"
  type        = string
  default     = "KMS key for encryption"
}

variable "key_usage" {
  description = "Intended use of the key"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "key_spec" {
  description = "Key spec for the KMS key"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
}

variable "key_administrators" {
  description = "List of IAM ARNs for key administrators"
  type        = list(string)
  default     = []
}

variable "key_users" {
  description = "List of IAM ARNs for key users"
  type        = list(string)
  default     = []
}

variable "key_service_users" {
  description = "List of IAM ARNs for service users"
  type        = list(string)
  default     = []
}

variable "service_principals" {
  description = "List of AWS service principals that can use the key"
  type        = list(string)
  default     = []
}

variable "additional_key_statements" {
  description = "Additional key policy statements"
  type = list(object({
    sid    = string
    effect = string
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "deletion_window_in_days" {
  description = "Number of days before the key is deleted"
  type        = number
  default     = 10
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "aliases" {
  description = "List of aliases for the key"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
