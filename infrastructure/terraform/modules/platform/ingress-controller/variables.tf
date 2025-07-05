# Platform Ingress Controller Variables

variable "config" {
  description = "Ingress controller configuration"
  type = object({
    enable_nginx_ingress = optional(bool, true)
    nginx_version       = optional(string, "4.8.3")
    service_type        = optional(string, "LoadBalancer")
    host_port_enabled   = optional(string, "false")
  })
  default = {
    enable_nginx_ingress = true
    nginx_version       = "4.8.3"
    service_type        = "LoadBalancer"
    host_port_enabled   = "false"
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}