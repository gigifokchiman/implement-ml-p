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
  default = {
    enable_resource_scheduling = true
    enable_cost_monitoring     = true
    enable_rightsizing         = true
    enable_spot_instances      = false
    enable_auto_scaling        = true
    schedule_downtime          = "0 19 * * 1-5" # 7 PM weekdays
    schedule_uptime            = "0 8 * * 1-5"  # 8 AM weekdays
    cost_budget_limit          = 1000           # $1000/month
    cost_alert_threshold       = 80             # 80% of budget
    rightsizing_schedule       = "0 2 * * 0"    # Weekly Sunday 2 AM
  }
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