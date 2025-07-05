# Development Environment Variables
variable "environment" {
  description = "environment"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "data-platform"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the EKS cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access to nodes"
  type        = string
  default     = null
}

# Node group configurations
variable "enable_gpu_nodes" {
  description = "Enable GPU node group"
  type        = bool
  default     = false
}

variable "gpu_node_config" {
  description = "GPU node group configuration"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["g4dn.xlarge"]
    min_size       = 0
    max_size       = 3
    desired_size   = 1
    disk_size      = 100
  }
}

variable "node_groups_config" {
  description = "Configuration for EKS node groups"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string
    disk_size      = number
  }))
  default = {
    core_services = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      capacity_type  = "SPOT"
      disk_size      = 50
    }
  }
}

# Team configurations
variable "team_namespaces" {
  description = "Team namespace configurations"
  type = map(object({
    resource_quota = object({
      cpu_requests    = string
      memory_requests = string
      cpu_limits      = string
      memory_limits   = string
      gpu_requests    = string
    })
    network_policies = bool
  }))
  default = {
    ml-team = {
      resource_quota = {
        cpu_requests    = "4"
        memory_requests = "8Gi"
        cpu_limits      = "8"
        memory_limits   = "16Gi"
        gpu_requests    = "2"
      }
      network_policies = true
    }
    data-team = {
      resource_quota = {
        cpu_requests    = "2"
        memory_requests = "4Gi"
        cpu_limits      = "4"
        memory_limits   = "8Gi"
        gpu_requests    = "0"
      }
      network_policies = true
    }
    core-team = {
      resource_quota = {
        cpu_requests    = "2"
        memory_requests = "4Gi"
        cpu_limits      = "4"
        memory_limits   = "8Gi"
        gpu_requests    = "0"
      }
      network_policies = true
    }
  }
}

# Storage configurations
variable "storage_config" {
  description = "Storage configuration"
  type = object({
    s3_buckets = map(object({
      versioning = bool
      encryption = bool
    }))
    rds = object({
      instance_class  = string
      allocated_storage = number
      backup_retention_period = number
    })
  })
  default = {
    s3_buckets = {
      ml_artifacts = {
        versioning = true
        encryption = true
      }
      data_lake = {
        versioning = true
        encryption = true
      }
    }
    rds = {
      instance_class           = "db.t3.micro"
      allocated_storage        = 20
      backup_retention_period  = 7
    }
  }
}

# Monitoring and observability
variable "monitoring_config" {
  description = "Monitoring stack configuration"
  type = object({
    enable_prometheus = bool
    enable_grafana    = bool
    enable_jaeger     = bool
    retention_days    = number
  })
  default = {
    enable_prometheus = true
    enable_grafana    = true
    enable_jaeger     = true
    retention_days    = 15
  }
}

# Security configurations
variable "security_config" {
  description = "Security configuration"
  type = object({
    enable_pod_security_standards = bool
    enable_network_policies       = bool
    enable_falco                  = bool
    pod_security_level           = string
  })
  default = {
    enable_pod_security_standards = true
    enable_network_policies       = true
    enable_falco                  = false
    pod_security_level           = "restricted"
  }
}

# GitOps configurations
variable "gitops_config" {
  description = "GitOps configuration"
  type = object({
    enable_argocd    = bool
    argocd_version   = string
    repo_url         = string
    target_revision  = string
  })
  default = {
    enable_argocd   = true
    argocd_version  = "v2.8.4"
    repo_url        = "https://github.com/your-org/infrastructure"
    target_revision = "HEAD"
  }
}
