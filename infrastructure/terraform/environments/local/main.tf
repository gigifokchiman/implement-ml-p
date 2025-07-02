# Local Development Environment Configuration
# Uses new modular composition approach

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
    }
  )
}

# KIND CLUSTER FOR LOCAL DEVELOPMENT
resource "kind_cluster" "default" {
  name           = "${local.shared_config.project_name}-local"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    nodes {
      role = "control-plane"

      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
    }

    nodes {
      role = "worker"
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

# Default storage class for Kind
resource "kubernetes_storage_class" "standard" {
  metadata {
    name = "standard"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  depends_on = [kind_cluster.default]
}

# ML Platform Composition
module "ml_platform" {
  source = "../../modules/compositions/ml-platform"

  name        = "${local.shared_config.project_name}-local"
  environment = "local"

  database_config = var.database_config
  cache_config    = var.cache_config
  storage_config  = var.storage_config

  tags = local.shared_config.common_tags

  depends_on = [kind_cluster.default, kubernetes_storage_class.standard]
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
  description = "All service connection details"
  value = {
    database   = module.ml_platform.database
    cache      = module.ml_platform.cache
    storage    = module.ml_platform.storage
    monitoring = module.ml_platform.monitoring
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
    kubectl_context         = "kubectl config use-context kind-${local.shared_config.project_name}-local"
    port_forward_db         = "kubectl port-forward -n database svc/postgres 5432:5432"
    port_forward_redis      = "kubectl port-forward -n cache svc/redis 6379:6379"
    port_forward_minio      = "kubectl port-forward -n storage svc/minio 9001:9000"
    port_forward_grafana    = "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    port_forward_prometheus = "kubectl port-forward -n monitoring svc/prometheus-server 9090:9090"
    minio_credentials       = "Access Key: admin, Secret: stored in secret 'minio-secret' in 'storage' namespace"
  }
}