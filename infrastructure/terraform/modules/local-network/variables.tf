# Local Network Simulation Module Variables

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (should be 'local')"
  type        = string
  default     = "local"
}

variable "cluster_name" {
  description = "Kind cluster name"
  type        = string
}

variable "enable_strict_policies" {
  description = "Enable strict network policies (more restrictive)"
  type        = bool
  default     = false
}

variable "allow_cross_subnet_communication" {
  description = "Allow communication between specific subnets"
  type = object({
    public_to_private           = optional(bool, true)
    private_to_database         = optional(bool, true)
    ml_workload_to_database     = optional(bool, true)
    data_processing_to_database = optional(bool, true)
    monitoring_to_all           = optional(bool, true)
  })
  default = {}
}

variable "internet_access_ports" {
  description = "Ports allowed for internet access"
  type = list(object({
    port     = number
    protocol = string
  }))
  default = [
    { port = 80, protocol = "TCP" },
    { port = 443, protocol = "TCP" },
    { port = 53, protocol = "TCP" },
    { port = 53, protocol = "UDP" }
  ]
}

variable "monitoring_ports" {
  description = "Ports used for monitoring access"
  type = list(object({
    port     = number
    protocol = string
  }))
  default = [
    { port = 9090, protocol = "TCP" }, # Prometheus
    { port = 8080, protocol = "TCP" }, # Metrics endpoints
    { port = 3000, protocol = "TCP" }, # Grafana
    { port = 9093, protocol = "TCP" }, # AlertManager
    { port = 9100, protocol = "TCP" }, # Node Exporter
  ]
}

variable "custom_subnets" {
  description = "Additional custom subnets to create"
  type = map(object({
    labels         = map(string)
    allow_ingress  = bool
    allow_internet = bool
    description    = string
  }))
  default = {}
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}