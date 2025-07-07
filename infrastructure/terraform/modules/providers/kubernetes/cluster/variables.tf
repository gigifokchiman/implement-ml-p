# Kind Cluster Provider Variables

variable "name" {
  description = "Cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (Kind will use default)"
  type        = string
  default     = "1.28"
}

variable "node_groups" {
  description = "Node groups configuration (adapted for Kind worker nodes)"
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
      instance_types = ["local"]
      capacity_type  = "ON_DEMAND"
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      ami_type       = "local"
      disk_size      = 50
      labels = {
        node-role    = "core-services"
        service-type = "infrastructure"
      }
      taints = {}
    }
  }
}

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

variable "tags" {
  description = "Tags to apply to resources (metadata only for Kind)"
  type        = map(string)
  default     = {}
}