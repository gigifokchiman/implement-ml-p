variable "namespace" {
  description = "Kubernetes namespace for observability components"
  type        = string
  default     = "ml-platform"
}

variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string
}

variable "enable_tracing" {
  description = "Enable distributed tracing with Jaeger"
  type        = bool
  default     = true
}

variable "tracing_sampling_rate" {
  description = "Sampling rate for traces (0.0 to 1.0)"
  type        = number
  default     = 0.1
}

variable "metrics_retention" {
  description = "Metrics retention period"
  type        = string
  default     = "30d"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}