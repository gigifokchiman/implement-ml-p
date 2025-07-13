# Platform Cluster Interface
# Provides unified interface for both Kind (local) and EKS (AWS) clusters


# AWS EKS Cluster Provider
module "aws_cluster" {
  count  = var.use_aws ? 1 : 0
  source = "../../providers/aws/cluster"

  name        = var.name
  environment = var.environment
  vpc_cidr    = var.vpc_cidr

  node_groups    = var.node_groups
  access_entries = var.access_entries

  enable_efs       = var.enable_efs
  enable_gpu_nodes = var.enable_gpu_nodes

  team_configurations = var.team_configurations

  tags = var.tags
}

# Kind Cluster Provider (Local)
module "kind_cluster" {
  count  = var.use_aws ? 0 : 1
  source = "../../providers/kubernetes/cluster"

  name        = var.name
  environment = var.environment

  node_groups   = var.node_groups
  port_mappings = var.port_mappings

  tags = var.tags
}

# Output unified interface
locals {
  cluster_info = var.use_aws ? {
    name               = module.aws_cluster[0].cluster_name
    endpoint           = module.aws_cluster[0].cluster_endpoint
    version            = module.aws_cluster[0].cluster_version
    ca_certificate     = module.aws_cluster[0].cluster_ca_certificate
    provider_type      = "aws"
    kubeconfig         = module.aws_cluster[0].kubeconfig
    vpc_id             = module.aws_cluster[0].vpc_id
    private_subnets    = module.aws_cluster[0].private_subnets
    public_subnets     = module.aws_cluster[0].public_subnets
    ecr_repository_url = module.aws_cluster[0].ecr_repository_url
    } : {
    name               = module.kind_cluster[0].cluster_name
    endpoint           = module.kind_cluster[0].cluster_endpoint
    version            = module.kind_cluster[0].cluster_version
    ca_certificate     = module.kind_cluster[0].cluster_ca_certificate
    provider_type      = "kind"
    kubeconfig         = module.kind_cluster[0].kubeconfig
    vpc_id             = null
    private_subnets    = []
    public_subnets     = []
    ecr_repository_url = null
  }
}
