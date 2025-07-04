# Template for creating new Kind clusters for applications
# Copy this file to terraform/environments/{app-name}/ and customize

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
  }
}

# Variables - customize these for your application
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "monitoring" # Change this
}

variable "http_port" {
  description = "HTTP port for ingress"
  type        = number
  default     = 9300 # Change this to avoid conflicts
}

variable "https_port" {
  description = "HTTPS port for ingress"
  type        = number
  default     = 9543 # Change this to avoid conflicts
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    username = string
    password = string
    database = string
  })
  default = {
    username = "admin"
    password = "changeme123"
    database = "app_db"
  }
}

variable "cache_config" {
  description = "Cache configuration"
  type = object({
    enabled = bool
  })
  default = {
    enabled = true
  }
}

variable "storage_config" {
  description = "Storage configuration"
  type = object({
    buckets = list(string)
  })
  default = {
    buckets = ["app-data", "app-artifacts"]
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
      app_name    = var.app_name
    }
  )
}

# KIND CLUSTER FOR YOUR APPLICATION
resource "kind_cluster" "app_cluster" {
  name           = "${var.app_name}-local"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\""
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = var.http_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = var.https_port
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }
  }
}

# Provider configurations
provider "kubernetes" {
  host                   = kind_cluster.app_cluster.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.app_cluster.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.app_cluster.client_certificate)
  client_key             = base64decode(kind_cluster.app_cluster.client_key)
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.app_cluster.endpoint
    cluster_ca_certificate = kind_cluster.app_cluster.cluster_ca_certificate
    client_certificate     = kind_cluster.app_cluster.client_certificate
    client_key             = kind_cluster.app_cluster.client_key
  }
}

# Stub AWS provider (required for module compatibility)
provider "aws" {
  region                      = "us-west-2"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  access_key                  = "dummy"
  secret_key                  = "dummy"
}

# Application Platform Composition
module "app_platform" {
  source = "../../modules/compositions/ml-platform"

  name        = "${var.app_name}-local"
  environment = "local"

  database_config = var.database_config
  cache_config    = var.cache_config
  storage_config  = var.storage_config

  tags = local.shared_config.common_tags

  depends_on = [kind_cluster.app_cluster]
}

# OUTPUTS
output "cluster_info" {
  description = "Kind cluster connection information"
  sensitive   = true
  value = {
    name                   = kind_cluster.app_cluster.name
    endpoint               = kind_cluster.app_cluster.endpoint
    kubeconfig_path        = kind_cluster.app_cluster.kubeconfig_path
    cluster_ca_certificate = kind_cluster.app_cluster.cluster_ca_certificate
  }
}

output "service_connections" {
  description = "Service connection details"
  value = {
    database   = module.app_platform.database
    cache      = module.app_platform.cache
    storage    = module.app_platform.storage
    monitoring = module.app_platform.monitoring
  }
  sensitive = true
}

output "development_urls" {
  description = "Local development URLs"
  value = {
    application = "http://localhost:${var.http_port}"
    grafana     = "http://localhost:3000" # Port forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
    prometheus  = "http://localhost:9090" # Port forward: kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
    minio       = "http://localhost:9001" # Port forward: kubectl port-forward -n storage svc/minio 9001:9000
  }
}

output "useful_commands" {
  description = "Useful commands for development"
  value = {
    kubectl_context         = "kubectl config use-context kind-${var.app_name}-local"
    port_forward_db         = "kubectl --context kind-${var.app_name}-local port-forward -n database svc/postgres 5432:5432"
    port_forward_redis      = "kubectl --context kind-${var.app_name}-local port-forward -n cache svc/redis 6379:6379"
    port_forward_minio      = "kubectl --context kind-${var.app_name}-local port-forward -n storage svc/minio 9001:9000"
    port_forward_grafana    = "kubectl --context kind-${var.app_name}-local port-forward -n monitoring svc/prometheus-grafana 3000:80"
    port_forward_prometheus = "kubectl --context kind-${var.app_name}-local port-forward -n monitoring svc/prometheus-server 9090:9090"
    list_clusters           = "kind get clusters"
    delete_cluster          = "kind delete cluster --name ${var.app_name}-local"
  }
}