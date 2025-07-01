# Local Development Environment Configuration
# Uses our custom provider for Kind cluster with local Docker registry

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
  }
}

# Provider configurations
provider "kind" {
  # Uses DOCKER_HOST env var if set
}

# Variables
variable "cluster_name" {
  description = "Kind cluster name"
  type        = string
  default     = "ml-platform-local"
}

variable "registry_port" {
  description = "Local registry port (NodePort)"
  type        = number
  default     = 30500
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

# Kind cluster configuration using internal provider
resource "kind_cluster" "default" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    nodes {
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

    nodes {
      role = "worker"
    }

    nodes {
      role = "worker"
    }
  }
}

# Note: Registry will be deployed inside the Kind cluster using Kubernetes
# This avoids the need for external Docker provider

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

# =============================================================================
# ML PLATFORM SERVICES MODULE
# =============================================================================

# Deploy comprehensive ML platform services
module "ml_platform_services" {
  source = "../../modules/local-services"

  cluster_name = var.cluster_name
  namespace    = "ml-platform"
  environment  = "local"

  # Enable development mode for local testing
  development_mode = {
    enabled           = true
    minimal_resources = true
    allow_insecure    = true
    debug_logging     = false
  }

  # Configure resource quotas for local development
  resource_quotas = {
    enabled = true
    compute = {
      requests_cpu    = "2"
      requests_memory = "4Gi"
      limits_cpu      = "4"
      limits_memory   = "8Gi"
    }
    storage = {
      requests_storage = "100Gi"
    }
  }

  # Customize service configurations for local environment
  postgresql_config = {
    storage_size = "10Gi"
    resources = {
      requests = {
        memory = "128Mi"
        cpu    = "100m"
      }
      limits = {
        memory = "256Mi"
        cpu    = "250m"
      }
    }
  }

  redis_config = {
    storage_size = "5Gi"
    resources = {
      requests = {
        memory = "64Mi"
        cpu    = "50m"
      }
      limits = {
        memory = "128Mi"
        cpu    = "100m"
      }
    }
  }

  minio_config = {
    storage_size = "20Gi"
    resources = {
      requests = {
        memory = "128Mi"
        cpu    = "100m"
      }
      limits = {
        memory = "256Mi"
        cpu    = "250m"
      }
    }
  }

  ingress_config = {
    http_port  = 8080
    https_port = 8443
    tls = {
      common_name = "*.${var.cluster_name}.local"
      dns_names   = ["${var.cluster_name}.local", "localhost"]
    }
  }

  # Enable monitoring and observability
  enable_monitoring       = true
  enable_network_policies = true
  enable_metrics_server   = true

  additional_labels = {
    "ml-platform/deployment" = "local"
    "ml-platform/managed-by" = "terraform"
  }

  depends_on = [kind_cluster.default]
}

# Legacy namespace resource (keep for backward compatibility)
resource "kubernetes_namespace" "ml_platform" {
  metadata {
    name = "ml-platform-legacy"
    labels = {
      name       = "ml-platform-legacy"
      deprecated = "true"
    }
  }
}

# Local registry secret for Kind cluster
# Uses the in-cluster registry deployed by the ml_platform_services module
resource "kubernetes_secret" "registry_credentials" {
  metadata {
    name      = "registry-credentials"
    namespace = module.ml_platform_services.namespace
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "localhost:${var.registry_port}" = {
          username = ""
          password = ""
          auth     = base64encode(":")
        }
        "${module.ml_platform_services.registry_connection.internal_endpoint}" = {
          username = ""
          password = ""
          auth     = base64encode(":")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "cluster_info" {
  description = "Kind cluster connection information"
  sensitive   = true
  value = {
    name                   = kind_cluster.default.name
    endpoint               = kind_cluster.default.endpoint
    kubeconfig_path        = kind_cluster.default.kubeconfig_path
    local_registry_url     = "localhost:${var.registry_port}"
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  }
}

output "ml_platform_services" {
  description = "ML Platform services connection details"
  value       = module.ml_platform_services.connection_details
  sensitive   = true
}

output "development_urls" {
  description = "Local development environment URLs"
  value = merge(
    {
      # Legacy URLs
      frontend       = "http://localhost:8080"
      registry_ui    = "http://localhost:${var.registry_port}/v2/_catalog"
      kubernetes_api = kind_cluster.default.endpoint
    },
    # ML Platform service URLs
    module.ml_platform_services.development_urls
  )
}

output "service_endpoints" {
  description = "Internal service endpoints for application configuration"
  value = {
    # Database
    postgresql = {
      host     = module.ml_platform_services.postgresql_connection.host
      port     = module.ml_platform_services.postgresql_connection.port
      database = module.ml_platform_services.postgresql_connection.database
      url      = module.ml_platform_services.postgresql_connection.url
    }

    # Cache
    redis = {
      host = module.ml_platform_services.redis_connection.host
      port = module.ml_platform_services.redis_connection.port
      url  = module.ml_platform_services.redis_connection.url
    }

    # Object Storage
    minio = {
      endpoint   = module.ml_platform_services.minio_connection.endpoint
      access_key = module.ml_platform_services.minio_connection.access_key
      buckets    = module.ml_platform_services.minio_connection.buckets
    }

    # Registry
    docker_registry = {
      internal_url = module.ml_platform_services.registry_connection.internal_endpoint
      external_url = module.ml_platform_services.registry_connection.external_endpoint
    }
  }
  sensitive = true
}

output "local_commands" {
  description = "Useful commands for local development"
  sensitive   = true
  value = merge(
    {
      # Legacy commands
      kubectl_context = "kubectl config use-context kind-${var.cluster_name}"
      registry_push   = "docker tag myimage:latest localhost:${var.registry_port}/myimage:latest && docker push localhost:${var.registry_port}/myimage:latest"
      deploy_apps     = "kubectl apply -k ../../kubernetes/overlays/local"
    },
    # ML Platform service commands
    module.ml_platform_services.useful_commands
  )
}

output "environment_summary" {
  description = "Complete local environment summary"
  value = {
    cluster = {
      name       = kind_cluster.default.name
      endpoint   = kind_cluster.default.endpoint
      nodes      = 3
      node_types = ["control-plane", "worker", "worker"]
    }

    services = {
      postgresql = "PostgreSQL 16 with 10Gi storage"
      redis      = "Redis 7 with 5Gi storage"
      minio      = "MinIO S3-compatible with 20Gi storage (3 buckets)"
      ingress    = "NGINX Ingress Controller with TLS"
      registry   = "Docker Registry 2 (in-cluster) with NodePort 30500"
    }

    namespace = module.ml_platform_services.namespace

    access = {
      ingress_http  = "http://localhost:8080"
      ingress_https = "https://localhost:8443"
      registry      = "http://localhost:${var.registry_port}"
    }

    monitoring = {
      metrics_server   = "Enabled"
      network_policies = "Enabled"
      resource_quotas  = "Enabled"
    }

    node_simulation = {
      general_workload = "Simulates m5.large instances"
      data_processing  = "Simulates c5.2xlarge instances with taints"
      ml_workload      = "Simulates m5.xlarge instances with taints"
      gpu_workload     = "Simulates g4dn.xlarge instances (no GPU)"
    }
  }
}