# Development Environment - AWS EKS
# Uses data-platform composition with AWS provider

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "dev/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

# AWS Provider
provider "aws" {
  region = var.region
}

# Locals
locals {
  name_prefix = var.cluster_name

  common_tags = {
    "Environment" = var.environment
    "Project"     = "data-platform"
    "ManagedBy"   = "terraform"
  }

  # Node groups configuration with GPU support
  node_groups = merge(
    var.node_groups_config,
    var.enable_gpu_nodes ? {
      gpu = {
        instance_types = var.gpu_node_config.instance_types
        capacity_type  = "ON_DEMAND" # GPU instances work better with on-demand
        min_size       = var.gpu_node_config.min_size
        max_size       = var.gpu_node_config.max_size
        desired_size   = var.gpu_node_config.desired_size
        ami_type       = "AL2_x86_64_GPU"
        disk_size      = var.gpu_node_config.disk_size
        labels = {
          node-role   = "gpu"
          gpu-type    = "nvidia"
          team-access = "ml-team"
          environment = "dev"
        }
        taints = {
          gpu = {
            key    = "nvidia.com/gpu"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
          ml_team = {
            key    = "team"
            value  = "ml"
            effect = "NO_SCHEDULE"
          }
        }
      }
    } : {}
  )
}

# Data Platform Composition
module "data_platform" {
  source = "../../modules/compositions/data-platform"

  name               = "data-platform"
  cluster_name       = var.name_prefix
  environment        = var.environment
  use_aws            = true
  kubernetes_version = var.kubernetes_version
  vpc_cidr           = var.vpc_cidr

  # Node groups
  node_groups = local.node_groups

  # Access entries for team members
  access_entries = var.access_entries

  # AWS features
  enable_efs       = var.enable_efs
  enable_gpu_nodes = var.enable_gpu_nodes

  # Team configurations
  team_configurations = var.team_namespaces



  # Platform services configuration
  database_config = {
    engine         = "postgres"
    version        = "16"
    instance_class = var.storage_config.rds.instance_class
    storage_size   = var.storage_config.rds.allocated_storage
    multi_az       = false
    encrypted      = true
    username       = "admin"
    database_name  = "metadata"
    port           = 5432
  }
  cache_config = {
    engine    = "redis"
    version   = "7.0"
    node_type = "cache.t3.micro"
    num_nodes = 1
    encrypted = true
    port      = 6379
  }
  storage_config = {
    versioning_enabled = true
    encryption_enabled = true
    lifecycle_enabled  = true
    port               = 9000
    buckets = [
      {
        name   = "ml-artifacts"
        public = false
      },
      {
        name   = "data-lake"
        public = false
      }
    ]
  }

  # Security and compliance
  allowed_cidr_blocks = var.allowed_cidr_blocks
  aws_region          = var.region

  tags = local.common_tags
}

# Kubernetes and Helm providers using cluster outputs
provider "kubernetes" {
  host                   = module.data_platform.cluster_endpoint
  cluster_ca_certificate = base64decode(module.data_platform.cluster.ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.data_platform.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.data_platform.cluster_endpoint
    cluster_ca_certificate = base64decode(module.data_platform.cluster.ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.data_platform.cluster_name, "--region", var.region]
    }
  }
}
