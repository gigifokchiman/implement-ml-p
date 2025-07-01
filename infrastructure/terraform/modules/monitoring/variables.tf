variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Target namespace for monitoring"
  type        = string
  default     = "ml-platform"
}

variable "create_namespace" {
  description = "Create a separate monitoring namespace"
  type        = bool
  default     = true
}

# Prometheus configuration
variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "Prometheus Helm chart version"
  type        = string
  default     = "51.3.0"
}

variable "metrics_retention" {
  description = "Prometheus metrics retention period"
  type        = string
  default     = "30d"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "10Gi"
}

variable "expose_prometheus_ui" {
  description = "Expose Prometheus UI via ingress"
  type        = bool
  default     = false
}

# Grafana configuration
variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "5Gi"
}

variable "expose_grafana_ui" {
  description = "Expose Grafana UI via ingress"
  type        = bool
  default     = true
}

variable "grafana_hostname" {
  description = "Grafana hostname for ingress"
  type        = string
  default     = "grafana.local"
}

# AlertManager configuration
variable "enable_alertmanager" {
  description = "Enable AlertManager"
  type        = bool
  default     = true
}

variable "alertmanager_storage_size" {
  description = "AlertManager storage size"
  type        = string
  default     = "2Gi"
}

# Node Exporter configuration
variable "enable_node_exporter" {
  description = "Enable Node Exporter"
  type        = bool
  default     = true
}

# Storage configuration
variable "enable_persistent_storage" {
  description = "Enable persistent storage for monitoring components"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "gp2"
}

variable "development_mode" {
  description = "Enable development mode with minimal resources"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ServiceMonitor configuration
variable "ml_workload_namespaces" {
  description = "List of namespaces containing ML workloads"
  type        = list(string)
  default     = ["ml-platform", "ml-platform-local-ml-workload"]
}

variable "data_processing_namespaces" {
  description = "List of namespaces containing data processing workloads"
  type        = list(string)
  default     = ["ml-platform", "ml-platform-local-data-processing"]
}

variable "application_namespaces" {
  description = "List of namespaces containing application services"
  type        = list(string)
  default     = ["ml-platform", "ml-platform-local-private"]
}

variable "frontend_namespaces" {
  description = "List of namespaces containing frontend services"
  type        = list(string)
  default     = ["ml-platform", "ml-platform-local-public"]
}