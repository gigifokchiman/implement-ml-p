variable "service_name" {
  description = "Name of the service to handle errors for"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "health_checks" {
  description = "Health check configuration"
  type = object({
    enabled              = bool
    endpoint             = optional(string, "/health")
    schedule             = optional(string, "*/2 * * * *")
    timeout_seconds      = optional(number, 30)
    last_check_status    = optional(string, "unknown")
    consecutive_failures = optional(number, 0)
    error_rate           = optional(number, 0.0)
  })
  default = {
    enabled = false
  }
}

variable "retry_policy" {
  description = "Retry policy configuration"
  type = object({
    max_retries    = number
    initial_delay  = string
    max_delay      = string
    backoff_factor = number
    jitter_enabled = bool
  })
  default = {
    max_retries    = 3
    initial_delay  = "1s"
    max_delay      = "60s"
    backoff_factor = 2
    jitter_enabled = true
  }
}

variable "circuit_breaker_config" {
  description = "Circuit breaker configuration"
  type = object({
    enabled            = bool
    failure_threshold  = number
    recovery_timeout   = string
    half_open_requests = number
  })
  default = {
    enabled            = false
    failure_threshold  = 5
    recovery_timeout   = "60s"
    half_open_requests = 3
  }
}

variable "fallback_config" {
  description = "Fallback configuration"
  type = object({
    strategy        = string # "cache", "static", "degraded", "none"
    cache_ttl       = optional(string, "300s")
    static_response = optional(string, "{\"status\":\"degraded\"}")
  })
  default = {
    strategy = "none"
  }
}

variable "error_thresholds" {
  description = "Error rate thresholds for different actions"
  type = object({
    max_error_rate    = number # 0.0 to 1.0
    alert_rate        = number
    scale_down_rate   = number
    restart_threshold = number # consecutive failures
  })
  default = {
    max_error_rate    = 0.1  # 10% error rate
    alert_rate        = 0.05 # 5% error rate triggers alert
    scale_down_rate   = 0.3  # 30% error rate triggers scale down
    restart_threshold = 5    # 5 consecutive failures triggers restart
  }
}

variable "auto_recovery" {
  description = "Automatic recovery configuration"
  type = object({
    enabled              = bool
    strategy             = string # "restart", "scale", "rollback", "manual"
    max_retries          = number
    backoff_strategy     = string # "linear", "exponential", "fixed"
    notification_webhook = optional(string, "")
  })
  default = {
    enabled          = false
    strategy         = "manual"
    max_retries      = 3
    backoff_strategy = "exponential"
  }
}