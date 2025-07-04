# Security Bootstrap Module Variables

variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "cert_manager_config" {
  description = "Configuration for cert-manager"
  type = object({
    version               = string
    enable_cluster_issuer = bool
    letsencrypt_email     = string
  })
  default = {
    version               = "v1.13.2"
    enable_cluster_issuer = true
    letsencrypt_email     = "admin@example.com"
  }
}

variable "nginx_config" {
  description = "Configuration for NGINX ingress controller"
  type = object({
    version      = string
    enable_ssl   = bool
    default_cert = string
  })
  default = {
    version      = "v1.8.2"
    enable_ssl   = true
    default_cert = "default-ssl-certificate"
  }
}

variable "argocd_config" {
  description = "Configuration for ArgoCD"
  type = object({
    version        = string
    enable_ui      = bool
    admin_password = string
    enable_dex     = bool
    enable_tls     = optional(bool, false)
  })
  default = {
    version        = "5.51.4"
    enable_ui      = true
    admin_password = ""
    enable_dex     = false
    enable_tls     = false
  }
}

variable "prometheus_config" {
  description = "Configuration for Prometheus Operator"
  type = object({
    version                = string
    enable_grafana         = bool
    grafana_admin_password = string
    storage_class          = string
    retention_days         = string
  })
  default = {
    version                = "55.5.0"
    enable_grafana         = true
    grafana_admin_password = "admin"
    storage_class          = ""
    retention_days         = "15d"
  }
}