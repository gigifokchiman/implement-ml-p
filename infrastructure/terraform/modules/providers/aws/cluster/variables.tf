# AWS EKS Cluster Provider Variables

variable "name" {
  description = "Cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
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

variable "node_groups" {
  description = "EKS node groups configuration"
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
  description = "EKS access entries"
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
  description = "Enable EFS for persistent storage"
  type        = bool
  default     = false
}

variable "efs_throughput" {
  description = "EFS provisioned throughput in MiB/s"
  type        = number
  default     = 100
}

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
    max_size       = 2
    desired_size   = 0
    disk_size      = 100
  }
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
    allowed_registries = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
