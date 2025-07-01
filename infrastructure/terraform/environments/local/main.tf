# Local Development Environment Configuration
# Uses modular approach for reusability and maintainability

terraform {
  required_version = ">= 1.0"
  required_providers {
    kind = {
      source  = "gigifokchiman/kind"
      version = "0.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Common configuration module
module "common" {
  source = "../../modules/common"

  project_name          = var.project_name
  environment           = var.environment
  region                = var.region
  common_tags           = var.common_tags
  enable_monitoring     = var.enable_monitoring
  enable_backup         = var.enable_backup
  backup_retention_days = var.backup_retention_days
  deletion_protection   = var.deletion_protection
  resource_quotas       = var.resource_quotas
  network_config        = var.network_config
  database_config       = var.database_config
  cache_config          = var.cache_config
  storage_config        = var.storage_config
  registry_config       = var.registry_config
  kubernetes_config     = var.kubernetes_config
  security_config       = var.security_config
  development_mode      = var.development_mode
}

# Provider configurations
provider "kind" {
  # Uses DOCKER_HOST env var if set
}

# KIND CLUSTER FOR LOCAL DEVELOPMENT
resource "kind_cluster" "default" {
  name           = module.common.name_prefix
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    nodes {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true,Environment=${module.common.environment},Project=${var.project_name}\""
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
      extra_port_mappings {
        container_port = 30500
        host_port      = 30500
        protocol       = "TCP"
      }
    }

    nodes {
      role = "worker"

      kubeadm_config_patches = [
        "kind: JoinConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"Environment=${module.common.environment},Project=${var.project_name}\""
      ]
    }

    nodes {
      role = "worker"

      kubeadm_config_patches = [
        "kind: JoinConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"Environment=${module.common.environment},Project=${var.project_name}\""
      ]
    }
  }
}

# Provider configurations for Kind cluster
provider "kubernetes" {
  host                   = kind_cluster.default.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.default.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.default.client_certificate)
  client_key             = base64decode(kind_cluster.default.client_key)
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.default.endpoint
    cluster_ca_certificate = base64decode(kind_cluster.default.cluster_ca_certificate)
    client_certificate     = base64decode(kind_cluster.default.client_certificate)
    client_key             = base64decode(kind_cluster.default.client_key)
  }
}

# LOCAL NETWORK (VPC SIMULATION) MODULE
module "local_network" {
  source = "../../modules/local-network"

  name_prefix  = module.common.name_prefix
  environment  = module.common.environment
  cluster_name = kind_cluster.default.name

  # Enable stricter policies in non-development mode
  enable_strict_policies = !module.common.is_development

  # Configure cross-subnet communication
  allow_cross_subnet_communication = {
    public_to_private           = true
    private_to_database         = true
    ml_workload_to_database     = true
    data_processing_to_database = true
    monitoring_to_all           = true
  }

  tags = module.common.common_tags

  depends_on = [kind_cluster.default]
}

# DATABASE MODULE (deployed to database subnet)
module "database" {
  source = "../../modules/database"

  name_prefix           = module.common.name_prefix
  environment           = module.common.environment
  namespace             = module.local_network.subnet_namespaces["database"]
  config                = module.common.database_config
  backup_retention_days = module.common.database_config.storage_size > 20 ? var.backup_retention_days : 1
  deletion_protection   = var.deletion_protection
  enable_monitoring     = var.enable_monitoring
  development_mode      = module.common.is_development
  local_storage_class   = "standard"
  tags                  = module.common.common_tags

  depends_on = [module.local_network]
}

# CACHE MODULE (deployed to database subnet)
module "cache" {
  source = "../../modules/cache"

  name_prefix           = module.common.name_prefix
  environment           = module.common.environment
  namespace             = module.local_network.subnet_namespaces["database"]
  config                = module.common.cache_config
  backup_retention_days = var.backup_retention_days
  development_mode      = module.common.is_development
  local_storage_class   = "standard"
  tags                  = module.common.common_tags

  depends_on = [module.local_network]
}

# STORAGE MODULE (deployed to private subnet)
module "storage" {
  source = "../../modules/storage"

  name_prefix         = module.common.name_prefix
  environment         = module.common.environment
  namespace           = module.local_network.subnet_namespaces["private"]
  config              = var.storage_config
  development_mode    = module.common.is_development
  local_storage_class = "standard"
  tags                = module.common.common_tags

  depends_on = [module.local_network]
}

# MONITORING MODULE (deployed to monitoring subnet)
module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix               = module.common.name_prefix
  environment               = module.common.environment
  namespace                 = module.local_network.subnet_namespaces["monitoring"]
  create_namespace          = false # namespace created by local_network module
  enable_prometheus         = var.enable_monitoring
  enable_grafana            = var.enable_monitoring
  enable_alertmanager       = var.enable_monitoring
  enable_node_exporter      = var.enable_monitoring
  enable_persistent_storage = true
  storage_class             = "standard"
  development_mode          = module.common.is_development
  expose_grafana_ui         = true
  grafana_hostname          = "${module.common.name_prefix}.local"
  grafana_admin_password    = "admin123"

  # Configure ServiceMonitors for VPC simulation subnets
  ml_workload_namespaces     = [module.local_network.subnet_namespaces["ml-workload"]]
  data_processing_namespaces = [module.local_network.subnet_namespaces["data-processing"]]
  application_namespaces     = [module.local_network.subnet_namespaces["private"]]
  frontend_namespaces        = [module.local_network.subnet_namespaces["public"]]

  tags = module.common.common_tags

  depends_on = [module.local_network]
}

# Legacy Kubernetes namespace for ML Platform (now using private subnet)
resource "kubernetes_namespace" "ml_platform" {
  metadata {
    name = "ml-platform-legacy"
    labels = merge(
      {
        name                              = "ml-platform-legacy"
        "app.kubernetes.io/part-of"       = "ml-platform"
        "network.ml-platform/subnet-type" = "private"
        deprecated                        = "true"
      },
      module.common.common_tags
    )
  }

  depends_on = [module.local_network]
}

# Resource quotas (if enabled)
resource "kubernetes_resource_quota" "ml_platform" {
  count = var.resource_quotas.enabled ? 1 : 0

  metadata {
    name      = "ml-platform-quota"
    namespace = kubernetes_namespace.ml_platform.metadata[0].name
  }

  spec {
    hard = merge(
      var.resource_quotas.compute != null ? {
        "requests.cpu"    = module.common.resource_quotas.compute.requests_cpu
        "requests.memory" = module.common.resource_quotas.compute.requests_memory
        "limits.cpu"      = module.common.resource_quotas.compute.limits_cpu
        "limits.memory"   = module.common.resource_quotas.compute.limits_memory
      } : {},
      var.resource_quotas.storage != null ? {
        "requests.storage" = module.common.resource_quotas.storage.requests_storage
      } : {}
    )
  }
}

# Cross-subnet connection secrets for applications in private subnet
resource "kubernetes_secret" "database_connection" {
  metadata {
    name      = "database-connection"
    namespace = module.local_network.subnet_namespaces["private"]
    labels = {
      "network.ml-platform/secret-type"   = "cross-subnet-connection"
      "network.ml-platform/target-subnet" = "database"
    }
  }

  data = {
    url = module.database.connection.url
  }

  type = "Opaque"
}

resource "kubernetes_secret" "redis_connection" {
  metadata {
    name      = "redis-connection"
    namespace = module.local_network.subnet_namespaces["private"]
    labels = {
      "network.ml-platform/secret-type"   = "cross-subnet-connection"
      "network.ml-platform/target-subnet" = "database"
    }
  }

  data = {
    url = module.cache.connection.url
  }

  type = "Opaque"
}

resource "kubernetes_secret" "s3_connection" {
  metadata {
    name      = "s3-connection"
    namespace = module.local_network.subnet_namespaces["private"]
    labels = {
      "network.ml-platform/secret-type"   = "storage-connection"
      "network.ml-platform/target-subnet" = "private"
    }
  }

  data = {
    endpoint   = module.storage.connection.endpoint
    access_key = module.storage.credentials.access_key
    secret_key = module.storage.credentials.secret_key
    buckets    = jsonencode(module.storage.connection.buckets)
  }

  type = "Opaque"
}

# OUTPUTS
output "cluster_info" {
  description = "Kind cluster connection information"
  sensitive   = true
  value = {
    name                   = kind_cluster.default.name
    endpoint               = kind_cluster.default.endpoint
    kubeconfig_path        = kind_cluster.default.kubeconfig_path
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  }
}

output "service_connections" {
  description = "Service connection details"
  sensitive   = true
  value = {
    database   = module.database.connection
    cache      = module.cache.connection
    storage    = module.storage.connection
    monitoring = module.monitoring.monitoring_endpoints
  }
}

output "development_urls" {
  description = "Local development URLs"
  value = {
    grafana    = module.monitoring.grafana_external_url
    prometheus = "http://localhost:9090" # Port forward required
    frontend   = "http://localhost:8080"
    registry   = "http://localhost:30500"
  }
}

output "cluster_name" {
  description = "Name of the Kind cluster"
  value       = kind_cluster.default.name
}

output "useful_commands" {
  description = "Useful commands for local development"
  sensitive   = true
  value = merge(
    {
      kubectl_context = "kubectl config use-context kind-${module.common.name_prefix}"
      apply_k8s       = "kubectl apply -k ../../../kubernetes/overlays/local"

      # VPC simulation commands
      list_subnets          = "kubectl get namespaces -l network.ml-platform/vpc-simulation=true"
      view_network_policies = "kubectl get networkpolicies --all-namespaces -l network.ml-platform/managed-by=terraform"
    },
    # Monitoring commands from the monitoring module
    module.monitoring.useful_commands
  )
}

output "vpc_simulation" {
  description = "VPC simulation details"
  value       = module.local_network.vpc_simulation
}

output "subnet_information" {
  description = "VPC subnet simulation information"
  value       = module.local_network.subnets
}

output "subnet_deployment_guide" {
  description = "Guide for deploying to VPC simulation subnets"
  value       = module.local_network.subnet_deployment_guide
}

output "vpc_comparison" {
  description = "Comparison between AWS VPC and local simulation"
  value       = module.local_network.vpc_comparison
}

output "monitoring_guide" {
  description = "Guide for teams to add monitoring to their services"
  value       = module.monitoring.service_discovery_guide
}

output "environment_summary" {
  description = "Environment summary"
  value = {
    environment = module.common.environment
    name_prefix = module.common.name_prefix
    is_local    = module.common.is_local

    vpc_simulation = {
      enabled          = true
      subnets          = length(module.local_network.subnet_namespaces)
      network_policies = "VPC-like behavior with Kubernetes NetworkPolicies"
    }

    services = {
      database   = "PostgreSQL in database subnet (${module.local_network.subnet_namespaces["database"]})"
      cache      = "Redis in database subnet (${module.local_network.subnet_namespaces["database"]})"
      storage    = "MinIO in private subnet (${module.local_network.subnet_namespaces["private"]})"
      monitoring = "Prometheus + Grafana in monitoring subnet (${module.local_network.subnet_namespaces["monitoring"]})"
    }

    monitoring = {
      prometheus_enabled   = var.enable_monitoring
      grafana_enabled      = var.enable_monitoring
      alertmanager_enabled = var.enable_monitoring
      service_discovery    = "Automatic via ServiceMonitors and PodMonitors"
      dashboards           = "ML Platform, Training, Data Processing, Infrastructure"
      alerts               = "Training jobs, data processing, infrastructure health"
    }

    security = {
      network_policies   = true
      pod_security       = true
      vpc_simulation     = "Network segmentation using Kubernetes namespaces"
      cross_subnet_rules = "Controlled communication between subnets"
    }

    deployment_targets = {
      frontend_apps    = module.local_network.subnet_namespaces["public"]
      backend_services = module.local_network.subnet_namespaces["private"]
      databases        = module.local_network.subnet_namespaces["database"]
      ml_training      = module.local_network.subnet_namespaces["ml-workload"]
      data_processing  = module.local_network.subnet_namespaces["data-processing"]
      monitoring_stack = module.local_network.subnet_namespaces["monitoring"]
    }
  }
}