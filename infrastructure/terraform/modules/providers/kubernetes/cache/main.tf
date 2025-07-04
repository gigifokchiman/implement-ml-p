# Kubernetes Redis implementation

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

resource "kubernetes_namespace" "cache" {
  metadata {
    name = "cache"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "cache"
      "app.kubernetes.io/component" = "cache"
      "workload-type"               = "cache"
    })
  }
}

# No PVC for local dev - using emptyDir

resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.cache.metadata[0].name
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
            container_port = 6379
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
    namespace = kubernetes_namespace.cache.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "redis"
    }

    port {
      port        = 6379
      target_port = 6379
    }
  }
}