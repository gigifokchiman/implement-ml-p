# Local Environment Variables

variable "environment" {
  description = "environment"
  type        = string
  default     = "local"
}

# variable "region" {
#   description = "AWS region"
#   type        = string
#   default     = "us-west-2"
# }

variable "cluster_name" {
  description = "Cluster name"
  type        = string
  default     = "data-platform"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

# variable "vpc_cidr" {
#   description = "VPC CIDR block"
#   type        = string
#   default     = "10.0.0.0/16"
# }
#
# variable "allowed_cidr_blocks" {
#   description = "CIDR blocks allowed to access the EKS cluster"
#   type        = list(string)
#   default     = ["0.0.0.0/0"]  # Restrict this in production
# }
#
# variable "key_pair_name" {
#   description = "EC2 Key Pair name for SSH access to nodes"
#   type        = string
#   default     = null
# }

# Node group configurations
variable "enable_gpu_nodes" {
  description = "Enable GPU node group"
  type        = bool
  default     = false
}

variable "gpu_node_config" {
  description = "GPU node group configuration (adapted for Kind with Metal GPU)"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
    ami_type       = string
  })
  default = {
    instance_types = ["local"]  # Kind doesn't use instance types
    min_size       = 1
    max_size       = 1
    desired_size   = 1
    disk_size      = 50
    ami_type       = "local"    # Kind uses local Docker images
  }
}

variable "node_groups_config" {
  description = "Configuration for node groups (adapted for Kind)"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string
    disk_size      = number
    ami_type       = string
    labels         = map(string)
    taints         = map(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    core_services = {
      instance_types = ["local"]      # Kind doesn't use instance types, but maintain structure
      min_size       = 1
      max_size       = 1             # Kind typically has fewer nodes
      desired_size   = 1
      capacity_type  = "ON_DEMAND"   # Kind doesn't distinguish, but maintain structure
      disk_size      = 50
      ami_type       = "local"       # Kind uses local Docker images
      labels = {
        node-role    = "core-services"
        service-type = "infrastructure"
        environment  = "local"
      }
      taints = {}                    # No taints for core services
    }
  }
}

# Team configurations with flexible storage/database options
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
    network_policies = bool
    allowed_registries = optional(list(string), [])  # Optional for local environments
    
    # Storage configuration - teams can optionally define their storage needs
    storage_config = optional(object({
      enabled = bool
      config = object({
        port = optional(number, 9000)
        buckets = list(object({
          name = string
          policy = optional(string, "private")
        }))
      })
    }), {
      enabled = false
      config = {
        port = 9000
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

# Port mappings for Kind cluster
variable "port_mappings" {
  description = "Port mappings for Kind cluster"
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

# Environment-specific configuration objects (moved from composition layer)
variable "security_config" {
  description = "Security configuration"
  type = object({
    enable_cert_manager        = optional(bool, true)
    enable_pod_security        = optional(bool, true)
    enable_network_policies    = optional(bool, true)
    enable_rbac               = optional(bool, true)
    enable_argocd             = optional(bool, true)
    enable_letsencrypt_issuer = optional(bool, false)
    enable_selfsigned_issuer  = optional(bool, true)
    cert_manager_version      = optional(string, "v1.13.2")
    argocd_version           = optional(string, "5.51.6")
    pod_security_standard    = optional(string, "baseline")
    ingress_service_type     = optional(string, "LoadBalancer")
    ingress_host_port_enabled = optional(string, "false")
    argocd_service_type      = optional(string, "LoadBalancer")
    argocd_insecure          = optional(string, "false")
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
    enable_rotation    = optional(bool, true)
    rotation_days      = optional(number, 30)
    enable_encryption  = optional(bool, true)
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

# Platform feature toggles
variable "enable_monitoring" {
  description = "Enable monitoring services"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable audit logging"
  type        = bool
  default     = true
}

variable "enable_security_policies" {
  description = "Enable security policies"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup services"
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
