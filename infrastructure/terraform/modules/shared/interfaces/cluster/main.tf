# Cluster Interface Definition
# Defines the contract that cluster modules must implement

# Cluster Interface Outputs
variable "cluster_outputs" {
  description = "Cluster interface outputs"
  type = object({
    cluster_name     = string
    cluster_endpoint = string
    cluster_version  = string
    vpc_id           = optional(string)
    private_subnets  = optional(list(string))
    public_subnets   = optional(list(string))
    node_groups = optional(map(object({
      name   = string
      status = string
      capacity = object({
        min_size     = number
        max_size     = number
        desired_size = number
      })
    })))
    security_groups = optional(list(string))
    iam_roles       = optional(map(string))
    tags            = optional(map(string))
  })
  default = null
}

# Cluster Interface Functions
locals {
  cluster_interface = var.cluster_outputs != null ? {
    # Core cluster information
    name     = var.cluster_outputs.cluster_name
    endpoint = var.cluster_outputs.cluster_endpoint
    version  = var.cluster_outputs.cluster_version

    # Network information (AWS specific)
    vpc_id          = try(var.cluster_outputs.vpc_id, null)
    private_subnets = try(var.cluster_outputs.private_subnets, [])
    public_subnets  = try(var.cluster_outputs.public_subnets, [])
    security_groups = try(var.cluster_outputs.security_groups, [])

    # Node information
    node_groups = try(var.cluster_outputs.node_groups, {})

    # Identity and access
    iam_roles = try(var.cluster_outputs.iam_roles, {})

    # Metadata
    tags = try(var.cluster_outputs.tags, {})

    # Helper functions
    is_ready = var.cluster_outputs.cluster_name != null && var.cluster_outputs.cluster_name != ""
    is_aws   = var.cluster_outputs.vpc_id != null
    is_local = var.cluster_outputs.vpc_id == null
  } : null
}

output "cluster_interface" {
  description = "Standardized cluster interface"
  value       = local.cluster_interface
}