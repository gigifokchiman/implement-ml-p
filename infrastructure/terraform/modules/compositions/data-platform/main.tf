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
  port_mappings       = var.port_mappings

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

# Secret Store - Essential for credential management
module "secret_store" {
  source = "../../platform/secret-store"

  name        = "${var.name}-secrets"
  environment = var.environment
  use_aws     = var.use_aws
  
  # AWS uses Secrets Manager, Local uses Kubernetes secrets
  config = {
    enable_rotation    = var.environment == "prod"
    rotation_days      = var.environment == "prod" ? 30 : 90
    enable_encryption  = var.environment != "local"
    kms_key_id         = var.use_aws ? module.cluster.aws_cluster_outputs.kms_key_id : null
  }

  tags = var.tags
}

# Security Bootstrap - Certificate management, RBAC, Pod Security
module "security_bootstrap" {
  source = "../../platform/security-bootstrap"

  name        = "${var.name}-security-bootstrap"
  environment = var.environment
  cluster_name = module.cluster.cluster_name
  
  config = {
    enable_cert_manager     = true
    enable_pod_security     = var.environment != "local"
    enable_network_policies = var.environment != "local"
    enable_rbac            = true
    cert_manager_version   = "v1.13.2"
    pod_security_standard  = var.environment == "prod" ? "restricted" : "baseline"
  }

  tags = var.tags
  depends_on = [module.cluster]
}

# Audit Logging - Compliance and security monitoring
module "audit_logging" {
  count  = var.environment != "local" ? 1 : 0
  source = "../../platform/audit-logging"

  name        = "${var.name}-audit"
  environment = var.environment
  cluster_name = module.cluster.cluster_name
  
  config = {
    enable_api_audit    = true
    enable_webhook_audit = var.environment == "prod"
    retention_days      = var.environment == "prod" ? 90 : 30
    log_level          = var.environment == "prod" ? "Metadata" : "Request"
  }

  tags = var.tags
  depends_on = [module.cluster]
}