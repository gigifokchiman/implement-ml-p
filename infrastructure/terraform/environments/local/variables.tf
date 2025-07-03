# Variables for the modular local environment
# These variables will be populated from terraform.tfvars

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ml-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "local"
}

variable "region" {
  description = "Region identifier"
  type        = string
  default     = "local"
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_monitoring" {
  description = "Enable monitoring and observability stack"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup for stateful services"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

variable "resource_quotas" {
  description = "Resource quotas for the environment"
  type = object({
    enabled = bool
    compute = optional(object({
      requests_cpu    = string
      requests_memory = string
      limits_cpu      = string
      limits_memory   = string
    }))
    storage = optional(object({
      requests_storage = string
    }))
  })
  default = {
    enabled = false
  }
}

variable "network_config" {
  description = "Network configuration"
  type = object({
    vpc_cidr           = optional(string, "10.0.0.0/16")
    enable_nat_gateway = optional(bool, true)
    single_nat_gateway = optional(bool, false)
    availability_zones = optional(number, 2)
  })
  default = {}
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    engine         = optional(string, "postgres")
    version        = optional(string, "16")
    instance_class = optional(string, "local")
    storage_size   = optional(number, 10)
    multi_az       = optional(bool, false)
    encrypted      = optional(bool, false)
    username       = optional(string, "admin")
    database_name  = optional(string, "metadata")
  })
  default = {}
}

variable "cache_config" {
  description = "Cache configuration"
  type = object({
    engine    = optional(string, "redis")
    version   = optional(string, "7.0")
    node_type = optional(string, "local")
    num_nodes = optional(number, 1)
    encrypted = optional(bool, false)
  })
  default = {}
}

variable "storage_config" {
  description = "Object storage configuration"
  type = object({
    versioning_enabled = optional(bool, false)
    encryption_enabled = optional(bool, false)
    lifecycle_enabled  = optional(bool, false)
    buckets = optional(list(object({
      name   = string
      public = optional(bool, false)
      })), [
      {
        name   = "ml-artifacts"
        public = false
      },
      {
        name   = "data-lake"
        public = false
      },
      {
        name   = "model-registry"
        public = false
      }
    ])
  })
  default = {}
}

variable "registry_config" {
  description = "Container registry configuration"
  type = object({
    image_tag_mutability = optional(string, "MUTABLE")
    scan_on_push         = optional(bool, true)
    encryption_enabled   = optional(bool, true)
    repositories = optional(list(string), [
      "ml-platform/backend",
      "ml-platform/frontend",
      "ml-platform/data-processor",
      "ml-platform/ml-trainer",
      "data-platform/data-api",
      "data-platform/data-processor",
      "data-platform/stream-processor",
      "data-platform/data-quality"
    ])
  })
  default = {}
}

variable "kubernetes_config" {
  description = "Kubernetes cluster configuration"
  type = object({
    version                   = optional(string, "1.28")
    enable_irsa               = optional(bool, true)
    enable_ebs_csi            = optional(bool, true)
    enable_efs_csi            = optional(bool, false)
    enable_alb_ingress        = optional(bool, true)
    enable_cluster_autoscaler = optional(bool, true)
    node_groups = optional(list(object({
      name           = string
      instance_types = list(string)
      min_size       = number
      max_size       = number
      desired_size   = number
      disk_size      = optional(number, 20)
      labels         = optional(map(string), {})
      taints = optional(list(object({
        key    = string
        value  = string
        effect = string
      })), [])
    })), [])
  })
  default = {}
}

variable "security_config" {
  description = "Security configuration"
  type = object({
    enable_network_policies   = optional(bool, true)
    enable_pod_security       = optional(bool, true)
    enable_secrets_encryption = optional(bool, true)
    enable_audit_logging      = optional(bool, true)
    pod_security_standards    = optional(string, "restricted")
  })
  default = {}
}

variable "development_mode" {
  description = "Development mode configuration"
  type = object({
    enabled           = optional(bool, true)
    minimal_resources = optional(bool, true)
    allow_insecure    = optional(bool, true)
    debug_logging     = optional(bool, false)
    skip_tls          = optional(bool, true)
  })
  default = {}
}

variable "performance_monitoring_config" {
  description = "Performance monitoring configuration"
  type = object({
    enable_apm                 = optional(bool, false)
    enable_custom_metrics      = optional(bool, false)
    enable_distributed_tracing = optional(bool, false)
  })
  default = {
    enable_apm                 = false
    enable_custom_metrics      = false
    enable_distributed_tracing = false
  }
}

variable "backup_config" {
  description = "Backup configuration"
  type = object({
    enabled             = optional(bool, false)
    backup_schedule     = optional(string, "0 2 * * *")
    retention_days      = optional(number, 1)
    enable_cross_region = optional(bool, false)
    enable_encryption   = optional(bool, false)
  })
  default = {
    enabled             = false
    backup_schedule     = "0 2 * * *"
    retention_days      = 1
    enable_cross_region = false
    enable_encryption   = false
  }
}