# Platform GitOps Variables

variable "config" {
  description = "GitOps configuration"
  type = object({
    enable_argocd  = optional(bool, true)
    argocd_version = optional(string, "5.51.6")
    service_type   = optional(string, "LoadBalancer")
    insecure       = optional(string, "false")
  })
  default = {
    enable_argocd  = true
    argocd_version = "5.51.6"
    service_type   = "LoadBalancer"
    insecure       = "false"
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
