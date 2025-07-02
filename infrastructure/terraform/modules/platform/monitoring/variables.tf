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
    enable_prometheus   = bool
    enable_grafana      = bool
    enable_alertmanager = bool
    storage_size        = string
    retention_days      = number
  })
  default = {
    enable_prometheus   = true
    enable_grafana      = true
    enable_alertmanager = true
    storage_size        = "10Gi"
    retention_days      = 7
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}