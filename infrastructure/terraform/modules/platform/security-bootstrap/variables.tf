variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "is_kind_cluster" {
  description = "Whether this is a Kind cluster (affects ingress configuration)"
  type        = bool
  default     = true
}

variable "enable_letsencrypt" {
  description = "Enable Let's Encrypt ClusterIssuer for production"
  type        = bool
  default     = false
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}