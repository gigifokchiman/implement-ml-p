variable "name" {
  description = "Cost optimization instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Cost optimization configuration"
  type = object({
    enable_resource_scheduling = bool
    enable_cost_monitoring     = bool
    enable_rightsizing         = bool
    enable_spot_instances      = bool
    enable_auto_scaling        = bool
    schedule_downtime          = string
    schedule_uptime            = string
    cost_budget_limit          = number
    cost_alert_threshold       = number
    rightsizing_schedule       = string
  })
}

variable "namespaces" {
  description = "List of namespaces to optimize"
  type        = list(string)
  default     = ["database", "cache", "storage", "monitoring"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}