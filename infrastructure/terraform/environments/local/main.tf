# Local Development Environment Configuration
# Uses new modular composition approach

terraform {
  required_version = ">= 1.0"
  required_providers {
    kind = {
      source  = "kind.local/gigifokchiman/kind"
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
    # Note: AWS provider not needed for local environment
    # All services run as Kubernetes containers via Kind
  }
}

# Load shared configuration
locals {
  shared_config = yamldecode(file("../_shared/config.yaml"))
  environment_config = merge(
    local.shared_config,
    {
      environment = "local"
      is_local    = true
      # Add environment label to common tags
      common_tags = merge(local.shared_config.common_tags, {
        environment = "local"
      })
    }
  )
}

# KIND CLUSTER FOR DATA PLATFORM
resource "kind_cluster" "data_platform" {
  name           = "data-platform-local"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true,environment=local,cluster-name=data-platform-local,node-role=control-plane"
          taints:
          - key: node-role.kubernetes.io/control-plane
            effect: NoSchedule
        ---
        kind: ClusterConfiguration
        scheduler:
          extraArgs:
            bind-address: "0.0.0.0"
        controllerManager:
          extraArgs:
            bind-address: "0.0.0.0"
        EOT
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 8090
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8453
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"

      kubeadm_config_patches = [
        <<-EOT
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "environment=local,cluster-name=data-platform-local,node-role=core-services,service-type=infrastructure"
        EOT
      ]
    }
  }
}

# Provider configurations for ML Platform cluster
provider "kubernetes" {
  host                   = kind_cluster.data_platform.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.data_platform.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.data_platform.client_certificate)
  client_key             = base64decode(kind_cluster.data_platform.client_key)
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.data_platform.endpoint
    cluster_ca_certificate = base64decode(kind_cluster.data_platform.cluster_ca_certificate)
    client_certificate     = base64decode(kind_cluster.data_platform.client_certificate)
    client_key             = base64decode(kind_cluster.data_platform.client_key)
  }
}

# Provider configurations for Data Platform cluster
provider "kubernetes" {
  alias                  = "data_platform"
  host                   = kind_cluster.data_platform.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.data_platform.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.data_platform.client_certificate)
  client_key             = base64decode(kind_cluster.data_platform.client_key)
}

provider "helm" {
  alias = "data_platform"
  kubernetes {
    host                   = kind_cluster.data_platform.endpoint
    cluster_ca_certificate = base64decode(kind_cluster.data_platform.cluster_ca_certificate)
    client_certificate     = base64decode(kind_cluster.data_platform.client_certificate)
    client_key             = base64decode(kind_cluster.data_platform.client_key)
  }
}

# Stub AWS provider configuration (unused in local environment)
# Required because child modules reference AWS provider even with count = 0
provider "aws" {
  region                      = "us-west-2"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  access_key                  = "dummy"
  secret_key                  = "dummy"
}

# No storage class needed - using emptyDir volumes for local dev

# ML Platform Composition
# Commented out to avoid duplicate resource creation with data_platform
# Both were creating the same namespaces in the same cluster
# module "ml_platform" {
#   source = "../../modules/compositions/data-platform"
#
#   name        = "${local.shared_config.project_name}-local"
#   environment = "local"
#
#   database_config = var.database_config
#   cache_config    = var.cache_config
#   storage_config  = var.storage_config
#
#   tags = local.environment_config.common_tags
#
#   depends_on = [kind_cluster.data_platform]
# }

# Data Platform Composition (separate cluster)
module "data_platform" {
  source = "../../modules/compositions/data-platform"

  name        = "data-platform-local"
  environment = "local"

  database_config = var.database_config
  cache_config    = var.cache_config
  storage_config  = var.storage_config

  tags = local.environment_config.common_tags

  depends_on = [kind_cluster.data_platform]

  providers = {
    kubernetes = kubernetes.data_platform
    helm       = helm.data_platform
  }
}

# Storage Provisioner for Kind cluster
# Note: Kind automatically installs local-path-provisioner, so we skip custom installation
# module "storage_provisioner" {
#   source = "../../modules/providers/kubernetes/storage-provisioner"
#
#   tags = local.environment_config.common_tags
#
#   depends_on = [kind_cluster.data_platform]
# }

# Generate random passwords
resource "random_password" "argocd_admin" {
  length  = 16
  special = true
}

# Secret Store for Platform Secrets
module "secret_store" {
  source = "../../modules/secret-store"

  environment = "local"
  tags        = local.environment_config.common_tags

  argocd_admin_password   = random_password.argocd_admin.result
  grafana_admin_password  = "admin"
  postgres_admin_password = "password"
  redis_password          = ""
  minio_access_key        = "minioadmin"
  minio_secret_key        = "minioadmin"

  depends_on = [kind_cluster.data_platform]

  providers = {
    kubernetes = kubernetes.data_platform
  }
}

# Security Bootstrap for Data Platform
module "security_bootstrap" {
  source = "../../modules/security-bootstrap"

  environment  = "local"
  cluster_name = "data-platform-local"
  tags         = local.environment_config.common_tags

  cert_manager_config = {
    version               = "v1.13.2"
    enable_cluster_issuer = true
    letsencrypt_email     = "admin@example.com"
  }

  nginx_config = {
    version      = "v1.8.2"
    enable_ssl   = true
    default_cert = "default-ssl-certificate"
  }

  argocd_config = {
    version        = "5.51.4"
    enable_ui      = true
    admin_password = random_password.argocd_admin.result
    enable_dex     = false
    enable_tls     = true
  }

  prometheus_config = {
    version                = "55.5.0"
    enable_grafana         = true
    grafana_admin_password = "admin"
    storage_class          = ""
    retention_days         = "15d"
  }

  depends_on = [kind_cluster.data_platform]

  providers = {
    kubernetes = kubernetes.data_platform
    helm       = helm.data_platform
  }
}

# Audit Logging Configuration
module "audit_logging" {
  source = "../../modules/audit-logging"

  environment = "local"
  tags        = local.environment_config.common_tags

  depends_on = [kind_cluster.data_platform]

  providers = {
    kubernetes = kubernetes.data_platform
  }
}

# OUTPUTS
output "data_platform_cluster_info" {
  description = "Data Platform cluster connection information"
  sensitive   = true
  value = {
    name                   = kind_cluster.data_platform.name
    endpoint               = kind_cluster.data_platform.endpoint
    kubeconfig_path        = kind_cluster.data_platform.kubeconfig_path
    cluster_ca_certificate = kind_cluster.data_platform.cluster_ca_certificate
  }
}

output "data_platform_service_connections" {
  description = "Data Platform service connection details"
  value = {
    database   = module.data_platform.database
    cache      = module.data_platform.cache
    storage    = module.data_platform.storage
    monitoring = module.data_platform.monitoring
  }
  sensitive = true
}

output "development_urls" {
  description = "Local development URLs"
  value = {
    grafana    = "http://localhost:3000" # Port forward required: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
    prometheus = "http://localhost:9090" # Port forward required: kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
    minio      = "http://localhost:9001" # Port forward required: kubectl port-forward -n storage svc/minio 9001:9000
  }
}

output "useful_commands" {
  description = "Useful commands for local development"
  value = {
    # Data Platform cluster commands
    kubectl_context         = "kubectl config use-context kind-data-platform-local"
    port_forward_db         = "kubectl --context kind-data-platform-local port-forward -n data-platform-database svc/postgres 5432:5432"
    port_forward_redis      = "kubectl --context kind-data-platform-local port-forward -n data-platform-cache svc/redis 6379:6379"
    port_forward_minio      = "kubectl --context kind-data-platform-local port-forward -n data-platform-storage svc/minio 9000:9000"
    port_forward_grafana    = "kubectl --context kind-data-platform-local port-forward -n data-platform-monitoring svc/prometheus-grafana 3000:80"
    port_forward_prometheus = "kubectl --context kind-data-platform-local port-forward -n data-platform-monitoring svc/prometheus-server 9090:9090"

    # General info
    list_clusters     = "kind get clusters"
    minio_credentials = "Access Key: admin, Secret: stored in secret 'minio-secret' in 'data-platform-storage' namespace"
  }
}
