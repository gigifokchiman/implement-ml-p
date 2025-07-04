# Terraform + Helm Integration Module
# Infrastructure managed by Terraform, Applications by Helm

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kind = {
      source  = "kind.local/gigifokchiman/kind"
      version = "0.1.0"
    }
  }
}

# Variables
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment (local, dev, staging, prod)"
  type        = string
  default     = "local"
}

variable "cluster_config" {
  description = "Cluster configuration"
  type = object({
    name       = string
    node_count = number
    http_port  = number
    https_port = number
  })
}

variable "helm_config" {
  description = "Helm configuration"
  type = object({
    chart_version      = string
    database_enabled   = bool
    cache_enabled      = bool
    storage_enabled    = bool
    monitoring_enabled = bool
  })
  default = {
    chart_version      = "0.1.0"
    database_enabled   = true
    cache_enabled      = true
    storage_enabled    = true
    monitoring_enabled = true
  }
}

# 1. TERRAFORM CREATES INFRASTRUCTURE
resource "kind_cluster" "app_cluster" {
  name           = var.cluster_config.name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = var.cluster_config.http_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = var.cluster_config.https_port
        protocol       = "TCP"
      }
    }

    dynamic "node" {
      for_each = range(var.cluster_config.node_count - 1)
      content {
        role = "worker"
      }
    }
  }
}

# 2. TERRAFORM CREATES KUBERNETES RESOURCES
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.app_name
    labels = {
      "app.kubernetes.io/name"    = var.app_name
      "app.kubernetes.io/part-of" = "platform"
      environment                 = var.environment
      managed-by                  = "terraform"
    }
  }

  depends_on = [kind_cluster.app_cluster]
}

resource "kubernetes_secret" "app_config" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  data = {
    environment  = var.environment
    app_name     = var.app_name
    cluster_name = kind_cluster.app_cluster.name
  }

  type = "Opaque"
}

# 3. TERRAFORM INSTALLS HELM REPOSITORIES
resource "helm_repository" "bitnami" {
  name = "bitnami"
  url  = "https://charts.bitnami.com/bitnami"
}

resource "helm_repository" "prometheus_community" {
  name = "prometheus-community"
  url  = "https://prometheus-community.github.io/helm-charts"
}

# 4. TERRAFORM DEPLOYS APPLICATIONS VIA HELM
resource "helm_release" "platform" {
  name       = var.app_name
  repository = "file://../../../helm/charts"
  chart      = "platform-template"
  version    = var.helm_config.chart_version
  namespace  = kubernetes_namespace.app_namespace.metadata[0].name

  # Wait for deployment to complete
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # Helm values configuration
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      app_name           = var.app_name
      namespace          = kubernetes_namespace.app_namespace.metadata[0].name
      environment        = var.environment
      database_enabled   = var.helm_config.database_enabled
      cache_enabled      = var.helm_config.cache_enabled
      storage_enabled    = var.helm_config.storage_enabled
      monitoring_enabled = var.helm_config.monitoring_enabled
    })
  ]

  # Dynamic configuration based on Terraform variables
  set {
    name  = "app.name"
    value = var.app_name
  }

  set {
    name  = "app.environment"
    value = var.environment
  }

  set {
    name  = "database.enabled"
    value = var.helm_config.database_enabled
  }

  set {
    name  = "cache.enabled"
    value = var.helm_config.cache_enabled
  }

  set {
    name  = "storage.enabled"
    value = var.helm_config.storage_enabled
  }

  set {
    name  = "monitoring.enabled"
    value = var.helm_config.monitoring_enabled
  }

  # Reference Terraform-created resources
  set {
    name  = "app.configSecretName"
    value = kubernetes_secret.app_config.metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.app_namespace,
    kubernetes_secret.app_config,
    helm_repository.bitnami,
    helm_repository.prometheus_community
  ]
}

# 5. CONDITIONAL HELM RELEASES BASED ON TERRAFORM LOGIC
resource "helm_release" "monitoring" {
  count = var.helm_config.monitoring_enabled ? 1 : 0

  name       = "${var.app_name}-monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = kubernetes_namespace.app_namespace.metadata[0].name

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin123"
  }

  depends_on = [helm_release.platform]
}

# 6. POST-DEPLOYMENT KUBERNETES RESOURCES
resource "kubernetes_config_map" "post_deploy_info" {
  metadata {
    name      = "${var.app_name}-deployment-info"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  data = {
    terraform_version  = "1.6.0"
    helm_chart_version = var.helm_config.chart_version
    deployment_time    = timestamp()
    cluster_endpoint   = kind_cluster.app_cluster.endpoint
    useful_commands = jsonencode({
      helm_status  = "helm status ${var.app_name} -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
      helm_upgrade = "helm upgrade ${var.app_name} ./chart -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
      kubectl_pods = "kubectl get pods -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
      port_forward = "kubectl port-forward -n ${kubernetes_namespace.app_namespace.metadata[0].name} svc/${var.app_name}-api 8080:8080"
    })
  }

  depends_on = [helm_release.platform]
}

# Outputs
output "cluster_info" {
  description = "Cluster information"
  value = {
    name            = kind_cluster.app_cluster.name
    endpoint        = kind_cluster.app_cluster.endpoint
    kubeconfig_path = kind_cluster.app_cluster.kubeconfig_path
  }
}

output "helm_release_info" {
  description = "Helm release information"
  value = {
    name        = helm_release.platform.name
    namespace   = helm_release.platform.namespace
    version     = helm_release.platform.version
    status      = helm_release.platform.status
    chart       = helm_release.platform.chart
    app_version = helm_release.platform.app_version
  }
}

output "application_urls" {
  description = "Application access URLs"
  value = {
    application = "http://localhost:${var.cluster_config.http_port}"
    grafana     = var.helm_config.monitoring_enabled ? "http://localhost:3000" : "Not enabled"
    prometheus  = var.helm_config.monitoring_enabled ? "http://localhost:9090" : "Not enabled"
  }
}

output "useful_commands" {
  description = "Useful commands for managing the deployment"
  value = {
    kubectl_context   = "kubectl config use-context kind-${kind_cluster.app_cluster.name}"
    helm_status       = "helm status ${var.app_name} -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
    helm_upgrade      = "helm upgrade ${var.app_name} ./chart -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
    helm_rollback     = "helm rollback ${var.app_name} -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
    helm_uninstall    = "helm uninstall ${var.app_name} -n ${kubernetes_namespace.app_namespace.metadata[0].name}"
    terraform_destroy = "terraform destroy -auto-approve"
  }
}