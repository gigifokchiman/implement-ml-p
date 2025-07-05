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
    # allowed_registries removed for local - no registry restrictions needed
  }))
  default = {
    ml-team = {
      resource_quota = {
        cpu_requests    = "2"
        memory_requests = "4Gi"
        cpu_limits      = "4"
        memory_limits   = "8Gi"
        gpu_requests    = "1"  # Simulated for local
      }
      network_policies = false  # Relaxed for local development
    }
    data-team = {
      resource_quota = {
        cpu_requests    = "1"
        memory_requests = "2Gi"
        cpu_limits      = "2"
        memory_limits   = "4Gi"
        gpu_requests    = "0"
      }
      network_policies = false
    }
    core-team = {
      resource_quota = {
        cpu_requests    = "1"
        memory_requests = "2Gi"
        cpu_limits      = "2"
        memory_limits   = "4Gi"
        gpu_requests    = "0"
      }
      network_policies = false
    }
  }
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
