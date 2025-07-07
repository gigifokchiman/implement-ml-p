# Core Infrastructure Template - Managed by Terraform
# Use this as a base for new application clusters

terraform {
  required_version = ">= 1.0"
  required_providers {
    kind = {
      source  = "kind.local/gigifokchiman/kind"
      version = "0.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Variables
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "http_port" {
  description = "HTTP port for ingress"
  type        = number
  default     = 8080
}

variable "https_port" {
  description = "HTTPS port for ingress"
  type        = number
  default     = 8443
}

# Core Infrastructure: Cluster
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

# Core Infrastructure: Storage Class
resource "kubernetes_storage_class" "local_path" {
  metadata {
    name = "local-path"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  depends_on = [kind_cluster.app_cluster]
}

# Core Infrastructure: Application Namespace
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.app_name
    labels = {
      "app.kubernetes.io/name" = var.app_name
      "managed-by"             = "terraform"
    }
  }

  depends_on = [kind_cluster.app_cluster]
}

# Provider configuration
provider "kubernetes" {
  host                   = kind_cluster.app_cluster.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.app_cluster.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.app_cluster.client_certificate)
  client_key             = base64decode(kind_cluster.app_cluster.client_key)
}

# Outputs for Helm usage
output "cluster_info" {
  description = "Information needed for Helm deployment"
  value = {
    name            = kind_cluster.app_cluster.name
    context         = "kind-${kind_cluster.app_cluster.name}"
    namespace       = kubernetes_namespace.app_namespace.metadata[0].name
    app_name        = var.app_name
    http_port       = var.http_port
    https_port      = var.https_port
    kubeconfig_path = kind_cluster.app_cluster.kubeconfig_path
  }
}

output "helm_deploy_command" {
  description = "Command to deploy applications with Helm"
  value       = "helm install ${var.app_name} ./helm/charts/platform-template --namespace ${kubernetes_namespace.app_namespace.metadata[0].name} --set app.name=${var.app_name}"
}
