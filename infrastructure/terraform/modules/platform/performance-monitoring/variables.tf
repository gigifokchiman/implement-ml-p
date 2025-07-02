variable "name" {
  description = "Performance monitoring instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Performance monitoring configuration"
  type = object({
    enable_apm               = bool
    enable_distributed_trace = bool
    enable_custom_metrics    = bool
    enable_log_aggregation   = bool
    enable_alerting          = bool
    retention_days           = number
    sampling_rate            = number
    trace_storage_size       = string
    metrics_storage_size     = string
    log_storage_size         = string
  })
  default = {
    enable_apm               = true
    enable_distributed_trace = true
    enable_custom_metrics    = true
    enable_log_aggregation   = true
    enable_alerting          = true
    retention_days           = 30
    sampling_rate            = 0.1 # 10% sampling
    trace_storage_size       = "10Gi"
    metrics_storage_size     = "20Gi"
    log_storage_size         = "50Gi"
  }
}

variable "namespaces" {
  description = "List of namespaces to monitor"
  type        = list(string)
  default     = ["database", "cache", "storage", "monitoring"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}