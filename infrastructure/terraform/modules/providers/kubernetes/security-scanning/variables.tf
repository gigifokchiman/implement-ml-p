variable "name" {
  description = "Security scanning instance name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "config" {
  description = "Security scanning configuration"
  type = object({
    enable_image_scanning   = bool
    enable_vulnerability_db = bool
    enable_runtime_scanning = bool
    enable_compliance_check = bool
    scan_schedule           = string
    severity_threshold      = string
    enable_notifications    = bool
    webhook_url             = optional(string)
  })
}

variable "namespaces" {
  description = "List of namespaces to scan"
  type        = list(string)
  default     = ["database", "cache", "storage", "monitoring"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "create_namespace_only" {
  description = "Only create namespace, not deployments (for ArgoCD to manage)"
  type        = bool
  default     = true
}

variable "security_webhook_url" {
  description = "Webhook URL for security notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "registry_configs" {
  description = "Container registry configurations for scanning"
  type = list(object({
    name     = string
    endpoint = string
    username = string
    password = string
  }))
  default   = []
  sensitive = true
}

variable "webhook_ca_bundle" {
  description = "CA bundle for admission webhook TLS"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cluster_endpoint" {
  description = "Kubernetes cluster endpoint for CI/CD kubeconfig"
  type        = string
  default     = ""
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate for CI/CD kubeconfig"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_admission_webhook" {
  description = "Enable admission webhook for CI/CD enforcement (disable for initial testing)"
  type        = bool
  default     = false
}