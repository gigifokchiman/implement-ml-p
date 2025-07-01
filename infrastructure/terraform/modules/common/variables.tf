# Common variables shared across all environments
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ml-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with an alphanumeric character."
  }
}

variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: local, dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region or local region identifier"
  type        = string
  default     = "us-west-2"
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
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
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

# Database configuration
variable "database_config" {
  description = "Database configuration"
  type = object({
    engine         = optional(string, "postgres")
    version        = optional(string, "16")
    instance_class = optional(string, "db.t3.micro")
    storage_size   = optional(number, 20)
    multi_az       = optional(bool, false)
    encrypted      = optional(bool, true)
    username       = optional(string, "admin")
    database_name  = optional(string, "metadata")
  })
  default = {}
}

# Cache configuration
variable "cache_config" {
  description = "Cache configuration"
  type = object({
    engine    = optional(string, "redis")
    version   = optional(string, "7.0")
    node_type = optional(string, "cache.t3.micro")
    num_nodes = optional(number, 1)
    encrypted = optional(bool, true)
  })
  default = {}
}

# Object storage configuration
variable "storage_config" {
  description = "Object storage configuration"
  type = object({
    versioning_enabled = optional(bool, true)
    encryption_enabled = optional(bool, true)
    lifecycle_enabled  = optional(bool, true)
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

# Container registry configuration
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
      "ml-platform/ml-trainer"
    ])
  })
  default = {}
}

# Kubernetes configuration
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

# Security configuration
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

# Development mode configuration
variable "development_mode" {
  description = "Development mode configuration for local environments"
  type = object({
    enabled           = optional(bool, false)
    minimal_resources = optional(bool, false)
    allow_insecure    = optional(bool, false)
    debug_logging     = optional(bool, false)
    skip_tls          = optional(bool, false)
  })
  default = {}
}