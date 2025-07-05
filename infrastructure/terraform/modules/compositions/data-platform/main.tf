# ML Platform Composition Module
# Orchestrates all platform components

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    aws = {
      source = "hashicorp/aws"
    }
    kind = {
      source  = "kind.local/gigifokchiman/kind"
      version = "0.1.0"
    }
  }
}

# Cluster Infrastructure
module "cluster" {
  source = "../../platform/cluster"

  name               = var.cluster_name != "" ? var.cluster_name : var.name
  environment        = var.environment
  use_aws           = var.use_aws
  kubernetes_version = var.kubernetes_version
  vpc_cidr          = var.vpc_cidr

  node_groups    = var.node_groups
  access_entries = var.access_entries
  
  enable_efs       = var.enable_efs
  enable_gpu_nodes = var.enable_gpu_nodes
  
  team_configurations = var.team_configurations

  tags = var.tags
}

module "database" {
  source = "../../platform/database"

  name        = "${var.name}-database"
  environment = var.environment
  config      = var.database_config
  tags        = var.tags

  # AWS-specific variables (passed through from cluster when using AWS)
  vpc_id                = module.cluster.vpc_id
  subnet_ids            = module.cluster.private_subnets
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  backup_retention_days = 7
  deletion_protection   = var.environment == "prod"
}

module "cache" {
  source = "../../platform/cache"

  name        = "${var.name}-cache"
  environment = var.environment
  config      = var.cache_config
  tags        = var.tags

  # AWS-specific variables
  vpc_id              = module.cluster.vpc_id
  subnet_ids          = module.cluster.private_subnets
  allowed_cidr_blocks = var.allowed_cidr_blocks
}

module "storage" {
  source = "../../platform/storage"

  name        = "${var.name}-storage"
  environment = var.environment
  config      = var.storage_config
  tags        = var.tags

  # AWS-specific variables
  region = var.aws_region
  
  depends_on = [module.cluster]
}

module "monitoring" {
  count  = var.environment != "local" ? 1 : 0
  source = "../../platform/monitoring"

  name        = "${var.name}-monitoring"
  environment = var.environment
  config = {
    enable_prometheus   = true
    enable_grafana      = true
    enable_alertmanager = var.environment != "local"
    storage_size        = var.environment == "local" ? "5Gi" : "20Gi"
    retention_days      = var.environment == "local" ? 3 : 30
  }
  tags = var.tags
}

module "security" {
  count  = var.environment != "local" ? 1 : 0
  source = "../../platform/security"

  name        = "${var.name}-security"
  environment = var.environment
  config = {
    enable_network_policies  = true
    enable_pod_security      = true
    enable_admission_control = var.environment != "local"
    pod_security_standard    = var.environment == "prod" ? "restricted" : "baseline"
  }
  namespaces = ["database", "cache", "storage", "monitoring"]
  tags       = var.tags
}

module "backup" {
  count  = var.environment != "local" ? 1 : 0
  source = "../../platform/backup"

  name        = "${var.name}-backup"
  environment = var.environment
  config = {
    backup_schedule     = var.environment == "prod" ? "0 2 * * *" : "0 3 * * 0" # Daily for prod, weekly for others
    retention_days      = var.environment == "prod" ? 30 : 7
    enable_cross_region = var.environment == "prod"
    enable_encryption   = true
  }
  tags = var.tags
}

module "security_scanning" {
  source = "../../platform/security-scanning"

  name        = "${var.name}-security-scanning"
  environment = var.environment
  config = {
    enable_image_scanning   = var.environment != "local"
    enable_vulnerability_db = var.environment != "local" # Disable for local due to filesystem issues
    enable_runtime_scanning = var.environment != "local"
    enable_compliance_check = var.environment == "prod"
    scan_schedule           = var.environment == "prod" ? "0 1 * * *" : "0 2 * * 0" # Daily for prod, weekly for others
    severity_threshold      = var.environment == "prod" ? "HIGH" : "MEDIUM"
    enable_notifications    = var.environment != "local"
    webhook_url             = var.security_webhook_url
  }
  namespaces = ["database", "cache", "storage", "monitoring", "security-scanning"]
  tags       = var.tags
}

module "performance_monitoring" {
  source = "../../platform/performance-monitoring"

  name        = "${var.name}-performance"
  environment = var.environment
  config = {
    enable_apm               = var.environment != "local"
    enable_distributed_trace = var.environment != "local"
    enable_custom_metrics    = var.environment != "local" # Disable OTEL collector for local
    enable_log_aggregation   = var.environment != "local"
    enable_alerting          = var.environment != "local"
    retention_days           = var.environment == "prod" ? 90 : 30
    sampling_rate            = var.environment == "prod" ? 0.05 : 0.1 # 5% for prod, 10% for others
    trace_storage_size       = var.environment == "local" ? "5Gi" : "20Gi"
    metrics_storage_size     = var.environment == "local" ? "10Gi" : "50Gi"
    log_storage_size         = var.environment == "local" ? "20Gi" : "100Gi"
  }
  namespaces = ["database", "cache", "storage", "monitoring", "security-scanning", "performance-monitoring"]
  tags       = var.tags
}