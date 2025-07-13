# Kubernetes Redis implementation

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}


# No PVC for local dev - using emptyDir
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = var.namespace
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "redis"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:${var.config.version}"

          port {
            container_port = var.config.port
          }

          volume_mount {
            name       = "redis-storage"
            mount_path = "/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "redis-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = var.namespace
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "redis"
    }

    port {
      port        = var.config.port
      target_port = var.config.port
    }
  }
}
# # Kubernetes Redis implementation
#
# # Sanitize tags for Kubernetes compatibility
# locals {
#   k8s_tags = {
#     for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
#   }
# }
#
# # Use existing namespace if it exists, create if it doesn't
# resource "kubernetes_namespace" "cache" {
#   metadata {
#     name = var.name
#     labels = merge(local.k8s_tags, {
#       "app.kubernetes.io/name"      = "cache"
#       "app.kubernetes.io/component" = "cache"
#       "workload-type"               = "cache"
#     })
#   }
#
#   lifecycle {
#     ignore_changes = [
#       metadata[0].annotations
#     ]
#   }
# }
#
# # No PVC for local dev - using emptyDir
#
# resource "kubernetes_deployment" "redis" {
#   metadata {
#     name      = "redis"
#     namespace = var.name
#     labels = merge(local.k8s_tags, {
#       "app.kubernetes.io/name"      = "redis"
#       "app.kubernetes.io/component" = "cache"
#     })
#   }
#
#   spec {
#     replicas = 1
#
#     selector {
#       match_labels = {
#         "app.kubernetes.io/name" = "redis"
#       }
#     }
#
#     template {
#       metadata {
#         labels = {
#           "app.kubernetes.io/name" = "redis"
#         }
#       }
#
#       spec {
#         container {
#           name  = "redis"
#           image = "redis:${var.config.version}"
#
#           port {
#             container_port = var.config.port
#           }
#
#           volume_mount {
#             name       = "redis-storage"
#             mount_path = "/data"
#           }
#
#           resources {
#             requests = {
#               cpu    = "100m"
#               memory = "128Mi"
#             }
#             limits = {
#               cpu    = "500m"
#               memory = "256Mi"
#             }
#           }
#         }
#
#         volume {
#           name = "redis-storage"
#           empty_dir {}
#         }
#       }
#     }
#   }
# }
#
# resource "kubernetes_service" "redis" {
#   metadata {
#     name      = "redis"
#     namespace = var.name
#     labels = {
#       "app.kubernetes.io/name"      = "redis"
#       "app.kubernetes.io/component" = "cache"
#     }
#   }
#
#   spec {
#     selector = {
#       "app.kubernetes.io/name" = "redis"
#     }
#
#     port {
#       port        = var.config.port
#       target_port = var.config.port
#     }
#   }
# }
