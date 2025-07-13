variable "name" {
  description = "Platform name"
  type        = string
}

variable "cluster_name" {
  description = "Cluster name (defaults to platform name if not specified)"
  type        = string
  default     = ""
}

variable "use_aws" {
  description = "Use AWS EKS instead of local Kind cluster"
  type        = bool
  default     = false
}


variable "vpc_cidr" {
  description = "VPC CIDR block (AWS only)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_groups" {
  description = "Node groups configuration"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
    ami_type       = string
    disk_size      = number
    labels         = map(string)
    taints = map(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    core_services = {
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      ami_type       = "AL2_x86_64"
      disk_size      = 50
      labels = {
        node-role    = "core-services"
        service-type = "infrastructure"
      }
      taints = {}
    }
  }
}

variable "access_entries" {
  description = "EKS access entries (AWS only)"
  type = map(object({
    kubernetes_groups = list(string)
    principal_arn     = string
    policy_associations = map(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = list(string)
      })
    }))
  }))
  default = {}
}

variable "enable_efs" {
  description = "Enable EFS for persistent storage (AWS only)"
  type        = bool
  default     = false
}

variable "enable_gpu_nodes" {
  description = "Enable GPU node group"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "enable_security_policies" {
  description = "Enable additional security policies"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup services"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable audit logging"
  type        = bool
  default     = true
}

variable "enable_security_scanning" {
  description = "Enable security scanning services"
  type        = bool
  default     = true
}

variable "enable_performance_monitoring" {
  description = "Enable performance monitoring services"
  type        = bool
  default     = true
}

variable "team_configurations" {
  description = "Team-specific configurations"
  type = map(object({
    resource_quota = object({
      cpu_requests    = string
      memory_requests = string
      cpu_limits      = string
      memory_limits   = string
      gpu_requests    = string
    })
    network_policies   = bool
    allowed_registries = optional(list(string), []) # Optional for local environments

    # Storage configuration - teams can optionally define their storage needs
    storage_config = optional(object({
      enabled = bool
      config = object({
        port = optional(number, 9000)
        buckets = list(object({
          name   = string
          policy = optional(string, "private")
        }))
      })
      }), {
      enabled = false
      config = {
        port    = 9000
        buckets = []
      }
    })

    # Database configuration - teams can optionally define their database needs
    database_config = optional(object({
      enabled = bool
      config = object({
        engine         = string
        version        = string
        instance_class = string
        storage_size   = number
        multi_az       = bool
        encrypted      = bool
        username       = string
        database_name  = string
        port           = optional(number, 5432)
      })
      }), {
      enabled = false
      config = {
        engine         = "postgres"
        version        = "15"
        instance_class = "db.t3.micro"
        storage_size   = 20
        multi_az       = false
        encrypted      = true
        username       = "admin"
        database_name  = "appdb"
        port           = 5432
      }
    })
  }))
  default = {}
}

variable "port_mappings" {
  description = "Port mappings for Kind cluster (ignored for AWS)"
  type = list(object({
    container_port = number
    host_port      = number
    protocol       = string
  }))
  default = [
    {
      container_port = 80
      host_port      = 8080
      protocol       = "TCP"
    },
    {
      container_port = 443
      host_port      = 8443
      protocol       = "TCP"
    }
  ]
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "database_config" {
  description = "Database configuration (deprecated - use team_configurations instead)"
  type = object({
    engine         = string
    version        = string
    instance_class = string
    storage_size   = number
    multi_az       = bool
    encrypted      = bool
    username       = string
    database_name  = string
    port           = optional(number, 5432)
  })
  default = {
    engine         = "postgres"
    version        = "15"
    instance_class = "db.t3.micro"
    storage_size   = 20
    multi_az       = false
    encrypted      = true
    username       = "admin"
    database_name  = "deprecated"
    port           = 5432
  }
}

variable "cache_config" {
  description = "Cache configuration (deprecated - use team_configurations instead)"
  type = object({
    engine    = string
    version   = string
    node_type = string
    num_nodes = number
    encrypted = bool
    port      = optional(number, 6379)
  })
  default = {
    engine    = "redis"
    version   = "7.0"
    node_type = "cache.t3.micro"
    num_nodes = 1
    encrypted = false
    port      = 6379
  }
}

variable "storage_config" {
  description = "Storage configuration (deprecated - use team_configurations instead)"
  type = object({
    versioning_enabled = bool
    encryption_enabled = bool
    lifecycle_enabled  = bool
    port               = optional(number, 9000)
    buckets = list(object({
      name   = string
      public = bool
    }))
  })
  default = {
    versioning_enabled = false
    encryption_enabled = false
    lifecycle_enabled  = false
    port               = 9000
    buckets            = []
  }
}

# Legacy AWS-specific variables (now handled by cluster module, kept for compatibility)

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region (for AWS environments)"
  type        = string
  default     = ""
}

variable "security_webhook_url" {
  description = "Webhook URL for security notifications (optional)"
  type        = string
  default     = null
}

# Environment-specific configuration objects (moved from inline logic)
variable "security_config" {
  description = "Security configuration"
  type = object({
    enable_cert_manager       = optional(bool, true)
    enable_pod_security       = optional(bool, true)
    enable_network_policies   = optional(bool, true)
    enable_rbac               = optional(bool, true)
    enable_argocd             = optional(bool, true)
    enable_letsencrypt_issuer = optional(bool, false)
    enable_selfsigned_issuer  = optional(bool, true)
    cert_manager_version      = optional(string, "v1.13.2")
    argocd_version            = optional(string, "5.51.6")
    pod_security_standard     = optional(string, "baseline")
    ingress_service_type      = optional(string, "LoadBalancer")
    ingress_host_port_enabled = optional(string, "false")
    argocd_service_type       = optional(string, "LoadBalancer")
    argocd_insecure           = optional(string, "false")
  })
  default = {}
}

variable "monitoring_config" {
  description = "Monitoring configuration"
  type = object({
    enable_prometheus   = optional(bool, true)
    enable_grafana      = optional(bool, true)
    enable_alertmanager = optional(bool, true)
    storage_size        = optional(string, "20Gi")
    retention_days      = optional(number, 30)
  })
  default = {}
}

variable "performance_config" {
  description = "Performance monitoring configuration"
  type = object({
    enable_apm               = optional(bool, true)
    enable_distributed_trace = optional(bool, true)
    enable_custom_metrics    = optional(bool, true)
    enable_log_aggregation   = optional(bool, true)
    enable_alerting          = optional(bool, true)
    retention_days           = optional(number, 90)
    sampling_rate            = optional(number, 0.05)
    trace_storage_size       = optional(string, "20Gi")
    metrics_storage_size     = optional(string, "50Gi")
    log_storage_size         = optional(string, "100Gi")
  })
  default = {}
}

variable "security_scanning_config" {
  description = "Security scanning configuration"
  type = object({
    enable_image_scanning   = optional(bool, true)
    enable_vulnerability_db = optional(bool, true)
    enable_runtime_scanning = optional(bool, true)
    enable_compliance_check = optional(bool, true)
    scan_schedule           = optional(string, "0 1 * * *")
    severity_threshold      = optional(string, "HIGH")
    enable_notifications    = optional(bool, true)
  })
  default = {}
}

variable "secret_store_config" {
  description = "Secret store configuration"
  type = object({
    enable_rotation   = optional(bool, true)
    rotation_days     = optional(number, 30)
    enable_encryption = optional(bool, true)
  })
  default = {}
}

variable "backup_config" {
  description = "Backup configuration"
  type = object({
    backup_schedule     = optional(string, "0 2 * * *")
    retention_days      = optional(number, 30)
    enable_cross_region = optional(bool, true)
    enable_encryption   = optional(bool, true)
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
