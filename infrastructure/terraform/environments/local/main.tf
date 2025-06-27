# Local Development Environment Configuration
# Uses Kind cluster with local Docker registry for development when AWS is not available

terraform {
  required_version = ">= 1.0"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.9"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
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
}

# Provider configurations
provider "docker" {
  # Docker socket configuration - will use DOCKER_HOST env var if set
  # If DOCKER_HOST is not set, falls back to standard location
}

# Variables
variable "cluster_name" {
  description = "Kind cluster name"
  type        = string
  default     = "ml-platform-local"
}

variable "registry_port" {
  description = "Local registry port"
  type        = number
  default     = 5001
}

variable "registry_username" {
  description = "Local registry username"
  type        = string
  default     = "dev"
  sensitive   = true
}

variable "registry_password" {
  description = "Local registry password"
  type        = string
  default     = ""
  sensitive   = true
}

# Locals
locals {
  environment = "local"
  name_prefix = var.cluster_name

  common_tags = {
    "Environment" = local.environment
    "Project"     = "ml-platform"
    "ManagedBy"   = "terraform"
  }
}

# =============================================================================
# KIND CLUSTER FOR LOCAL DEVELOPMENT
# =============================================================================

# Kind cluster configuration
resource "kind_cluster" "default" {
  name = var.cluster_name

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

    node {
      role = "worker"
    }

    node {
      role = "worker"
    }
  }

  wait_for_ready = true
}

# Local Docker registry for Kind cluster
resource "docker_container" "registry" {
  image = "registry:2"
  name  = "kind-registry"

  ports {
    internal = 5000
    external = var.registry_port
  }

  volumes {
    container_path = "/var/lib/registry"
    host_path      = "${path.cwd}/registry-data"
  }

  env = [
    "REGISTRY_STORAGE_DELETE_ENABLED=true"
  ]

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.kind.name
  }
}

# Docker network for Kind cluster and registry
resource "docker_network" "kind" {
  name = "${var.cluster_name}-network"
}

# Provider configurations for Kind cluster
provider "kubernetes" {
  host                   = kind_cluster.default.endpoint
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.default.endpoint
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
    client_certificate     = kind_cluster.default.client_certificate
    client_key             = kind_cluster.default.client_key
  }
}

# Deploy applications to Kind cluster
resource "kubernetes_namespace" "ml_platform" {
  metadata {
    name = "ml-platform"
    labels = {
      name = "ml-platform"
    }
  }
}

# Local registry secret for Kind cluster
resource "kubernetes_secret" "registry_credentials" {
  metadata {
    name      = "registry-credentials"
    namespace = kubernetes_namespace.ml_platform.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "localhost:${var.registry_port}" = {
          username = var.registry_username
          password = var.registry_password
          auth     = base64encode("${var.registry_username}:${var.registry_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

# Outputs
output "cluster_info" {
  description = "Kind cluster connection information"
  value = {
    name                   = kind_cluster.default.name
    endpoint               = kind_cluster.default.endpoint
    kubeconfig_path        = kind_cluster.default.kubeconfig_path
    local_registry_url     = "localhost:${var.registry_port}"
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  }
}

output "development_urls" {
  description = "Local development environment URLs"
  value = {
    frontend       = "http://localhost:8080"
    registry_ui    = "http://localhost:${var.registry_port}/v2/_catalog"
    kubernetes_api = kind_cluster.default.endpoint
  }
}

output "local_commands" {
  description = "Useful commands for local development"
  value = {
    kubectl_context = "kubectl config use-context kind-${var.cluster_name}"
    registry_login  = "docker login localhost:${var.registry_port} -u ${var.registry_username} -p ${var.registry_password}"
    deploy_apps     = "kubectl apply -k ../../kubernetes/overlays/dev-kind"
  }
}