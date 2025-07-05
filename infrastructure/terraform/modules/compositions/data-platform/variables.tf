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

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
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
    taints         = map(object({
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
  description = "Database configuration"
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
}

variable "cache_config" {
  description = "Cache configuration"
  type = object({
    engine    = string
    version   = string
    node_type = string
    num_nodes = number
    encrypted = bool
    port      = optional(number, 6379)
  })
}

variable "storage_config" {
  description = "Storage configuration"
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}