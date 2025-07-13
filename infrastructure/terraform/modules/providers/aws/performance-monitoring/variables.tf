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
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
