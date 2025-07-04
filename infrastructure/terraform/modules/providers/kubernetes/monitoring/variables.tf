variable "name" {
  description = "Monitoring instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Monitoring configuration"
  type = object({
    enable_prometheus     = bool
    enable_grafana        = bool
    enable_alertmanager   = bool
    storage_size          = string
    retention_days        = number
    prometheus_version    = optional(string, "55.0.0")
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}