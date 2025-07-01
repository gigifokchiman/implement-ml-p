# Common outputs
output "name_prefix" {
  description = "Standardized name prefix for resources"
  value       = var.environment == "local" ? var.project_name : "${var.project_name}-${var.environment}"
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region" {
  description = "Region"
  value       = var.region
}

output "common_tags" {
  description = "Merged common tags"
  value = merge(
    {
      "Project"     = var.project_name
      "Environment" = var.environment
      "ManagedBy"   = "terraform"
      "Region"      = var.region
    },
    var.common_tags
  )
}

output "is_production" {
  description = "Whether this is a production environment"
  value       = var.environment == "prod"
}

output "is_development" {
  description = "Whether this is a development environment"
  value       = contains(["local", "dev"], var.environment)
}

output "is_local" {
  description = "Whether this is a local environment"
  value       = var.environment == "local"
}

output "resource_prefix" {
  description = "Resource prefix for naming"
  value       = replace(local.name_prefix, "-", "")
}

locals {
  name_prefix = var.environment == "local" ? var.project_name : "${var.project_name}-${var.environment}"
}

# Configuration outputs with environment-specific defaults
output "database_config" {
  description = "Database configuration with environment defaults"
  value = merge(var.database_config, {
    instance_class = var.environment == "prod" ? coalesce(var.database_config.instance_class, "db.r6g.large") : var.environment == "staging" ? coalesce(var.database_config.instance_class, "db.t3.small") : coalesce(var.database_config.instance_class, "db.t3.micro")
    multi_az       = var.environment == "prod" ? coalesce(var.database_config.multi_az, true) : coalesce(var.database_config.multi_az, false)
    storage_size   = var.environment == "prod" ? coalesce(var.database_config.storage_size, 100) : var.environment == "staging" ? coalesce(var.database_config.storage_size, 50) : coalesce(var.database_config.storage_size, 20)
  })
}

output "cache_config" {
  description = "Cache configuration with environment defaults"
  value = merge(var.cache_config, {
    node_type = var.environment == "prod" ? coalesce(var.cache_config.node_type, "cache.r6g.large") : var.environment == "staging" ? coalesce(var.cache_config.node_type, "cache.t3.small") : coalesce(var.cache_config.node_type, "cache.t3.micro")
    num_nodes = var.environment == "prod" ? coalesce(var.cache_config.num_nodes, 2) : coalesce(var.cache_config.num_nodes, 1)
  })
}

locals {
  default_node_groups = var.environment == "prod" ? [
    {
      name           = "general"
      instance_types = ["m5.large"]
      min_size       = 3
      max_size       = 10
      desired_size   = 3
      disk_size      = 20
      labels         = { role = "general" }
      taints         = []
    },
    {
      name           = "data-processing"
      instance_types = ["c5.2xlarge"]
      min_size       = 0
      max_size       = 20
      desired_size   = 2
      disk_size      = 50
      labels         = { role = "data-processing" }
      taints = [{
        key    = "workload"
        value  = "data"
        effect = "NO_SCHEDULE"
      }]
    },
    {
      name           = "ml-workload"
      instance_types = ["m5.xlarge", "m5.2xlarge"]
      min_size       = 0
      max_size       = 15
      desired_size   = 2
      disk_size      = 100
      labels         = { role = "ml-workload" }
      taints = [{
        key    = "workload"
        value  = "ml"
        effect = "NO_SCHEDULE"
      }]
    },
    {
      name           = "gpu-nodes"
      instance_types = ["g4dn.xlarge"]
      min_size       = 0
      max_size       = 5
      desired_size   = 0
      disk_size      = 200
      labels         = { role = "gpu-workload", "node.kubernetes.io/instance-type" = "gpu" }
      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
    ] : var.environment == "staging" ? [
    {
      name           = "general"
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      disk_size      = 20
      labels         = { role = "general" }
      taints         = []
    },
    {
      name           = "data-processing"
      instance_types = ["c5.xlarge"]
      min_size       = 0
      max_size       = 8
      desired_size   = 1
      disk_size      = 30
      labels         = { role = "data-processing" }
      taints = [{
        key    = "workload"
        value  = "data"
        effect = "NO_SCHEDULE"
      }]
    }
    ] : [
    {
      name           = "general"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size      = 20
      labels         = { role = "general" }
      taints         = []
    }
  ]
}

output "kubernetes_config" {
  description = "Kubernetes configuration with environment defaults"
  value = merge(var.kubernetes_config, {
    node_groups = length(var.kubernetes_config.node_groups) > 0 ? var.kubernetes_config.node_groups : local.default_node_groups
  })
}

output "network_config" {
  description = "Network configuration with environment defaults"
  value = merge(var.network_config, {
    single_nat_gateway = var.environment == "dev" ? coalesce(var.network_config.single_nat_gateway, true) : coalesce(var.network_config.single_nat_gateway, false)
    availability_zones = var.environment == "prod" ? coalesce(var.network_config.availability_zones, 3) : coalesce(var.network_config.availability_zones, 2)
  })
}