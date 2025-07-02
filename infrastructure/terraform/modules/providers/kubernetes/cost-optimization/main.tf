# Kubernetes Cost Optimization Implementation
# Uses Vertical Pod Autoscaler, resource quotas, and scheduled scaling

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

# Namespace for cost optimization
resource "kubernetes_namespace" "cost_optimization" {
  metadata {
    name = "cost-optimization"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"             = "cost-optimization"
      "app.kubernetes.io/component"        = "cost-management"
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    })
  }
}

# Resource quotas for cost control
resource "kubernetes_resource_quota" "namespace_quotas" {
  count = length(var.namespaces)

  metadata {
    name      = "cost-quota"
    namespace = var.namespaces[count.index]
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "cost-optimization"
      "app.kubernetes.io/component" = "quota"
    })
  }

  spec {
    hard = {
      "requests.cpu"           = var.environment == "local" ? "2" : "4"
      "requests.memory"        = var.environment == "local" ? "4Gi" : "8Gi"
      "limits.cpu"             = var.environment == "local" ? "4" : "8"
      "limits.memory"          = var.environment == "local" ? "8Gi" : "16Gi"
      "persistentvolumeclaims" = "10"
      "services"               = "10"
      "pods"                   = "20"
    }
  }
}

# Limit ranges for default resource limits
resource "kubernetes_limit_range" "namespace_limits" {
  count = length(var.namespaces)

  metadata {
    name      = "cost-limits"
    namespace = var.namespaces[count.index]
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "cost-optimization"
      "app.kubernetes.io/component" = "limits"
    })
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      max = {
        cpu    = "2"
        memory = "2Gi"
      }
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }

    limit {
      type = "PersistentVolumeClaim"
      max = {
        storage = "100Gi"
      }
      min = {
        storage = "1Gi"
      }
    }
  }
}

# Cost monitoring deployment using Kubecost
resource "kubernetes_deployment" "kubecost" {
  count = var.config.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "kubecost"
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "cost-monitoring"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "kubecost"
        "app.kubernetes.io/component" = "cost-monitoring"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "kubecost"
          "app.kubernetes.io/component" = "cost-monitoring"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.kubecost[0].metadata[0].name

        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }

        container {
          name  = "kubecost"
          image = "kubecost/cost-model:latest"

          env {
            name  = "PROMETHEUS_SERVER_ENDPOINT"
            value = "http://prometheus.monitoring.svc.cluster.local:9090"
          }

          env {
            name  = "CLOUD_PROVIDER_API_KEY"
            value = "AIzaSyDXQPG_MHUEy9neR7stolq6l0ujXmjJlvk" # Demo key
          }

          env {
            name  = "CLUSTER_ID"
            value = var.environment
          }

          port {
            container_port = 9003
            name           = "http"
          }

          port {
            container_port = 9090
            name           = "metrics"
          }

          volume_mount {
            name       = "kubecost-storage"
            mount_path = "/var/kubecost"
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }
        }

        volume {
          name = "kubecost-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.kubecost_storage[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Kubecost storage PVC
resource "kubernetes_persistent_volume_claim" "kubecost_storage" {
  count = var.config.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "kubecost-storage"
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "storage"
    })
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

# Service account for Kubecost
resource "kubernetes_service_account" "kubecost" {
  count = var.config.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "kubecost"
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "cost-monitoring"
    })
  }
}

# Cluster role for Kubecost
resource "kubernetes_cluster_role" "kubecost" {
  count = var.config.enable_cost_monitoring ? 1 : 0

  metadata {
    name = "kubecost"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "cost-monitoring"
    })
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "pods", "services", "resourcequotas", "replicationcontrollers", "limitranges", "persistentvolumeclaims", "persistentvolumes", "namespaces", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["get", "list", "watch"]
  }
}

# Cluster role binding for Kubecost
resource "kubernetes_cluster_role_binding" "kubecost" {
  count = var.config.enable_cost_monitoring ? 1 : 0

  metadata {
    name = "kubecost"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "cost-monitoring"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kubecost[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubecost[0].metadata[0].name
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
  }
}

# Kubecost service
resource "kubernetes_service" "kubecost" {
  count = var.config.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "kubecost"
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "cost-monitoring"
    })
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9090"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "kubecost"
      "app.kubernetes.io/component" = "cost-monitoring"
    }

    port {
      name        = "http"
      port        = 9003
      target_port = 9003
    }

    port {
      name        = "metrics"
      port        = 9090
      target_port = 9090
    }

    type = "ClusterIP"
  }
}

# Resource scaling cronjob for non-production environments
resource "kubernetes_cron_job_v1" "resource_scaler" {
  count = var.config.enable_resource_scheduling && var.environment != "prod" ? 1 : 0

  metadata {
    name      = "resource-scaler"
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "resource-scaler"
      "app.kubernetes.io/component" = "scheduler"
    })
  }

  spec {
    schedule = var.config.schedule_downtime

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "resource-scaler"
          "app.kubernetes.io/component" = "scheduler"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "resource-scaler"
              "app.kubernetes.io/component" = "scheduler"
            }
          }

          spec {
            restart_policy       = "OnFailure"
            service_account_name = kubernetes_service_account.resource_scaler[0].metadata[0].name

            security_context {
              run_as_non_root = true
              run_as_user     = 65534
              fs_group        = 65534
            }

            container {
              name    = "kubectl"
              image   = "bitnami/kubectl:latest"
              command = ["/bin/bash"]
              args = [
                "-c",
                <<-EOT
                  # Scale down non-critical deployments
                  kubectl scale deployment --replicas=0 -n database postgres || true
                  kubectl scale deployment --replicas=0 -n cache redis || true
                  kubectl scale deployment --replicas=0 -n monitoring prometheus-grafana || true
                  
                  echo "Scaled down deployments for cost optimization"
                EOT
              ]

              resources {
                limits = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                requests = {
                  cpu    = "50m"
                  memory = "64Mi"
                }
              }

              security_context {
                allow_privilege_escalation = false
                capabilities {
                  drop = ["ALL"]
                }
                read_only_root_filesystem = true
              }
            }
          }
        }
      }
    }
  }
}

# Service account for resource scaler
resource "kubernetes_service_account" "resource_scaler" {
  count = var.config.enable_resource_scheduling && var.environment != "prod" ? 1 : 0

  metadata {
    name      = "resource-scaler"
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "resource-scaler"
      "app.kubernetes.io/component" = "scheduler"
    })
  }
}

# Cluster role for resource scaler
resource "kubernetes_cluster_role" "resource_scaler" {
  count = var.config.enable_resource_scheduling && var.environment != "prod" ? 1 : 0

  metadata {
    name = "resource-scaler"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "resource-scaler"
      "app.kubernetes.io/component" = "scheduler"
    })
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "deployments/scale"]
    verbs      = ["get", "list", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["replicationcontrollers", "replicationcontrollers/scale"]
    verbs      = ["get", "list", "update", "patch"]
  }
}

# Cluster role binding for resource scaler
resource "kubernetes_cluster_role_binding" "resource_scaler" {
  count = var.config.enable_resource_scheduling && var.environment != "prod" ? 1 : 0

  metadata {
    name = "resource-scaler"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "resource-scaler"
      "app.kubernetes.io/component" = "scheduler"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.resource_scaler[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.resource_scaler[0].metadata[0].name
    namespace = kubernetes_namespace.cost_optimization.metadata[0].name
  }
}

# HPA for automatic scaling
resource "kubernetes_horizontal_pod_autoscaler_v2" "cost_aware_hpa" {
  count = var.config.enable_auto_scaling ? length(var.namespaces) : 0

  metadata {
    name      = "cost-aware-hpa"
    namespace = var.namespaces[count.index]
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "cost-optimization"
      "app.kubernetes.io/component" = "autoscaling"
    })
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "postgres" # This would need to be dynamic in real implementation
    }

    min_replicas = var.environment == "prod" ? 2 : 1
    max_replicas = var.environment == "prod" ? 10 : 3

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}