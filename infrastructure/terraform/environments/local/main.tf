# Local Development Environment - Kind Cluster
# Uses enterprise provider version management

# AWS Provider (stub for module compatibility) - minimal configuration for Kind-only setup
provider "aws" {
  region = "us-west-2"
  # mocks
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Use dummy credentials to avoid AWS SDK calls
  access_key = "dummy"
  secret_key = "dummy"
}

# Local only
data "external" "environment_check" {
  program = ["sh", "-c", <<-EOF
    # Check Docker socket
    if [ -S "$HOME/.docker/run/docker.sock" ]; then
      DOCKER_SOCKET="unix://$HOME/.docker/run/docker.sock"
    elif [ -S /var/run/docker.sock ]; then
      DOCKER_SOCKET="unix:///var/run/docker.sock"
    else
      DOCKER_SOCKET="unix:///var/run/docker.sock"
    fi

    # Check kubeconfig path (Docker container vs local)
    if [ -f "/workspace/.kube/config" ]; then
      KUBE_CONFIG="/workspace/.kube/config"
    elif [ -f "~/.kube/config" ]; then
      KUBE_CONFIG="~/.kube/config"
    elif [ -f "$HOME/.kube/config" ]; then
      KUBE_CONFIG="$HOME/.kube/config"
    else
      KUBE_CONFIG="~/.kube/config"
    fi

    echo "{\"socket_path\": \"$DOCKER_SOCKET\", \"kube_config\": \"$KUBE_CONFIG\"}"
  EOF
  ]
}

# Local only
provider "docker" {
  host = data.external.environment_check.result.socket_path
}

# Locals
locals {
  name_prefix = var.cluster_name

  common_tags = {
    "Environment" = var.environment
    "Project"     = "data-platform"
    "ManagedBy"   = "terraform"
  }

  # Node groups configuration with GPU support (adapted for Kind)
  node_groups = merge(
    var.node_groups_config,
    var.enable_gpu_nodes ? {
      gpu = {
        instance_types = ["local"] # Kind doesn't have instance types, but maintain structure
        capacity_type  = "ON_DEMAND"
        min_size       = 1
        max_size       = 1
        desired_size   = 1
        ami_type       = "local" # Kind uses local Docker images
        disk_size      = 50
        labels = {
          node-role   = "gpu"
          gpu-type    = "metal" # Use Metal for macOS GPU simulation
          team-access = "ml-team"
          environment = "local"
        }
        taints = {
          gpu = {
            key    = "metal.gpu/gpu" # Metal GPU taint instead of nvidia
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

  name         = "data-platform"
  cluster_name = local.name_prefix
  environment  = var.environment
  use_aws      = false # Use Kind cluster instead of AWS EKS
  # vpc_cidr   = var.vpc_cidr  # Not used for Kind clusters

  # Node groups
  node_groups = local.node_groups

  # Access entries for team members (commented for local - Kind uses kubeconfig)
  # access_entries = var.access_entries

  # AWS features (commented for local - not applicable to Kind)
  # enable_efs       = var.enable_efs
  enable_gpu_nodes = var.enable_gpu_nodes

  enable_monitoring             = var.enable_monitoring
  enable_audit_logging          = var.enable_audit_logging
  enable_security_policies      = var.enable_security_policies
  enable_backup                 = var.enable_backup
  enable_security_scanning      = var.enable_security_scanning
  enable_performance_monitoring = var.enable_performance_monitoring

  # Team configurations
  team_configurations = var.team_configurations

  # Local only
  port_mappings = var.port_mappings

  # Platform services configuration now managed per-team in team_configurations

  # Security and compliance
  allowed_cidr_blocks = ["0.0.0.0/0"] # vs var.allowed_cidr_blocks in dev (relaxed for local)
  # aws_region         = var.region     # Not applicable for Kind

  # Environment-specific configurations (moved from composition layer)
  security_config          = var.security_config
  monitoring_config        = var.monitoring_config
  performance_config       = var.performance_config
  security_scanning_config = var.security_scanning_config
  secret_store_config      = var.secret_store_config
  backup_config            = var.backup_config

  tags = local.common_tags
}

# Kubernetes and Helm providers using detected kubeconfig path
# Works both in Docker container and local environment
provider "kubernetes" {
  config_path    = data.external.environment_check.result.kube_config
  config_context = "kind-${module.data_platform.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = data.external.environment_check.result.kube_config
    config_context = "kind-${module.data_platform.cluster_name}"
  }
}
