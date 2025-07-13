# Platform Certificate Management Variables

variable "config" {
  description = "Certificate management configuration"
  type = object({
    enable_cert_manager       = optional(bool, true)
    enable_letsencrypt_issuer = optional(bool, false)
    enable_selfsigned_issuer  = optional(bool, true)
    cert_manager_version      = optional(string, "v1.13.2")
  })
  default = {
    enable_cert_manager       = true
    enable_letsencrypt_issuer = false
    enable_selfsigned_issuer  = true
    cert_manager_version      = "v1.13.2"
  }
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
