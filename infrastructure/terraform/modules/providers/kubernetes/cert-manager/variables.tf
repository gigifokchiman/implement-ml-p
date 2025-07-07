# Kubernetes Provider - Cert-Manager Variables

variable "config" {
  description = "Cert-manager configuration"
  type = object({
    enable_cert_manager  = optional(bool, true)
    cert_manager_version = optional(string, "v1.13.2")
  })
  default = {
    enable_cert_manager  = true
    cert_manager_version = "v1.13.2"
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}