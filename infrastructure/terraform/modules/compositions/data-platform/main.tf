# ML Platform Composition Module
# Orchestrates all platform components using dependency injection and service discovery

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

# Cross-cutting concerns for platform
module "platform_cross_cutting" {
  source = "../../shared/cross-cutting"
  
  platform_name     = var.name
  environment       = var.environment
  module_name       = "data-platform-composition"
  service_name      = var.name
  component_type    = "platform"
  service_type      = "infrastructure"
  service_tier      = "core"
  security_level    = "high"
  namespace         = "default"
  
  base_tags = var.tags
  
  logging_config = {
    enabled = true
    level   = var.environment == "local" ? "debug" : "info"
  }
  
  monitoring_config = {
    enabled = var.enable_monitoring
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

  tags = module.platform_cross_cutting.standard_tags
}

# Cluster interface for dependency injection
module "cluster_interface" {
  source = "../../shared/interfaces/cluster"
  
  cluster_outputs = {
    cluster_name     = module.cluster.cluster_name
    cluster_endpoint = module.cluster.cluster_endpoint
    cluster_version  = var.kubernetes_version
    vpc_id           = try(module.cluster.vpc_id, null)
    private_subnets  = try(module.cluster.private_subnets, null)
    public_subnets   = try(module.cluster.public_subnets, null)
    security_groups  = try(module.cluster.security_groups, null)
    iam_roles        = try(module.cluster.iam_roles, null)
    tags             = module.platform_cross_cutting.standard_tags
  }
}

module "database" {
  source = "../../platform/database"

  name        = "${var.name}-database"
  environment = var.environment
  config      = var.database_config
  tags        = var.tags

  # Provider-specific configuration (only populated for AWS environments)
  provider_config = {
    vpc_id                = try(module.cluster.vpc_id, "")
    subnet_ids            = try(module.cluster.private_subnets, [])
    allowed_cidr_blocks   = var.allowed_cidr_blocks
    backup_retention_days = 7
    deletion_protection   = var.environment == "prod"
    region                = try(var.aws_region, "")
  }
}

module "cache" {
  source = "../../platform/cache"

  name        = "${var.name}-cache"
  environment = var.environment
  config      = var.cache_config
  tags        = var.tags

  # Provider-specific configuration (only populated for AWS environments)
  provider_config = {
    vpc_id              = try(module.cluster.vpc_id, "")
    subnet_ids          = try(module.cluster.private_subnets, [])
    allowed_cidr_blocks = var.allowed_cidr_blocks
    region              = try(var.aws_region, "")
  }
}

module "storage" {
  source = "../../platform/storage"

  name        = "${var.name}-storage"
  environment = var.environment
  config      = var.storage_config
  tags        = var.tags

  # Provider-specific configuration (only populated for AWS environments)
  provider_config = {
    region = try(var.aws_region, "")
  }
  
  depends_on = [module.cluster]
}

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "../../platform/monitoring"

  name        = "${var.name}-monitoring"
  environment = var.environment
  config = var.monitoring_config
  tags = var.tags
}

module "security" {
  count  = var.enable_security_policies ? 1 : 0
  source = "../../platform/security"

  name        = "${var.name}-security"
  environment = var.environment
  config = {
    enable_network_policies  = true
    enable_pod_security      = true
    enable_admission_control = var.environment != "local"
    pod_security_standard    = var.environment == "prod" ? "restricted" : "baseline"
  }
  namespaces = [
    "${var.name}-database",
    "${var.name}-cache", 
    "${var.name}-storage",
    "${var.name}-monitoring"
  ]
  tags       = var.tags
}

module "backup" {
  count  = var.enable_backup ? 1 : 0
  source = "../../platform/backup"

  name        = "${var.name}-backup"
  environment = var.environment
  config = var.backup_config
  tags = var.tags
}

module "security_scanning" {
  count  = var.enable_security_scanning ? 1 : 0
  source = "../../platform/security-scanning"

  name        = "${var.name}-security-scanning"
  environment = var.environment
  config = merge(var.security_scanning_config, {
    webhook_url = var.security_webhook_url
  })
  create_namespace_only = true  # Let ArgoCD manage deployments
  tags                  = var.tags
}

module "performance_monitoring" {
  count  = var.enable_performance_monitoring ? 1 : 0
  source = "../../platform/performance-monitoring"

  name        = "${var.name}-performance"
  environment = var.environment
  config = var.performance_config
  namespaces = [
    "${var.name}-database",
    "${var.name}-cache",
    "${var.name}-storage",
    "${var.name}-monitoring", 
    "${var.name}-security-scanning",
    "${var.name}-performance-monitoring"
  ]
  tags       = var.tags
}

# Secret Store - Essential for credential management
module "secret_store" {
  source = "../../platform/secret-store"

  name        = "${var.name}-secrets"
  environment = var.environment
  use_aws     = var.use_aws
  
  # AWS uses Secrets Manager, Local uses Kubernetes secrets
  config = merge(var.secret_store_config, {
    kms_key_id = var.use_aws && can(module.cluster.aws_cluster_outputs.kms_key_id) ? module.cluster.aws_cluster_outputs.kms_key_id : null
  })

  tags = var.tags
}

# Security Bootstrap - Certificate management, RBAC, Pod Security (dependency injected)
module "security_bootstrap" {
  source = "../../platform/security-bootstrap"

  name         = "${var.name}-security-bootstrap"
  environment  = var.environment
  cluster_name = module.cluster.cluster_name
  
  # Dependency injection - inject cluster interface
  cluster_info = module.cluster_interface.cluster_interface
  
  config = var.security_config

  tags = module.platform_cross_cutting.standard_tags
}

# Audit Logging - Compliance and security monitoring
module "audit_logging" {
  count  = var.enable_audit_logging ? 1 : 0
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

# Security interface for service discovery
module "security_interface" {
  source = "../../shared/interfaces/security"
  
  security_outputs = {
    cert_manager_enabled     = module.security_bootstrap.security_info.cert_manager_enabled
    cert_manager_namespace   = module.security_bootstrap.security_info.cert_manager_namespace
    cluster_issuer          = module.security_bootstrap.security_info.cluster_issuer
    ingress_class           = module.security_bootstrap.security_info.ingress_class
    ingress_namespace       = module.security_bootstrap.security_info.ingress_namespace
    argocd_enabled          = module.security_bootstrap.security_info.argocd_enabled
    argocd_namespace        = module.security_bootstrap.security_info.argocd_namespace
    pod_security_enabled    = module.security_bootstrap.security_info.pod_security_enabled
    network_policies_enabled = module.security_bootstrap.security_info.network_policies_enabled
    rbac_enabled            = module.security_bootstrap.security_info.rbac_enabled
  }
}

# Interface Validation
module "interface_validation" {
  source = "../../shared/validation"
  
  cluster_interface  = module.cluster_interface.cluster_interface
  security_interface = module.security_interface.security_interface
  
  provider_config = {
    vpc_id                = try(module.cluster.vpc_id, "")
    subnet_ids            = try(module.cluster.private_subnets, [])
    allowed_cidr_blocks   = var.allowed_cidr_blocks
    backup_retention_days = 7
    deletion_protection   = var.environment == "prod"
    region                = try(var.aws_region, "")
  }
}

# Service Discovery Registry (disabled until ArgoCD manages namespaces)
module "service_registry" {
  source = "../../shared/service-registry"
  
  platform_name = var.name
  environment   = var.environment
  
  cluster_service = module.cluster_interface.cluster_interface
  security_service = module.security_interface.security_interface
  
  enable_service_registry = false  # Disabled until platform-system namespace exists
  enable_health_checks    = false  # Disabled - managed by ArgoCD
  
  depends_on = [module.interface_validation]
  
  additional_services = {
    database = {
      name     = "database"
      type     = "database"
      status   = "ready"
      metadata = {
        engine = var.database_config.engine
        version = var.database_config.version
      }
    }
    cache = {
      name     = "cache"
      type     = "cache"
      status   = "ready"
      metadata = {
        engine = var.cache_config.engine
        version = var.cache_config.version
      }
    }
    storage = {
      name     = "storage"
      type     = "storage"
      status   = "ready"
      metadata = {
        versioning = tostring(var.storage_config.versioning_enabled)
        encryption = tostring(var.storage_config.encryption_enabled)
      }
    }
    monitoring = var.enable_monitoring ? {
      name     = "monitoring"
      type     = "observability"
      status   = "ready"
      metadata = {
        prometheus = tostring(var.monitoring_config.enable_prometheus)
        grafana = tostring(var.monitoring_config.enable_grafana)
      }
    } : null
  }
}