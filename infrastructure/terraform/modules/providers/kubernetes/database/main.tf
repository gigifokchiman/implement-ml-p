# Kubernetes PostgreSQL implementation

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

resource "random_password" "postgres_password" {
  length  = 16
  special = false
}

# Database namespace is managed by the shared data platform namespace
# resource "kubernetes_namespace" "database" {
#   metadata {
#     name = var.name
#     labels = merge(local.k8s_tags, {
#       "app.kubernetes.io/name"      = "database"
#       "app.kubernetes.io/component" = "database"
#       "workload-type"               = "database"
#     })
#   }

#   lifecycle {
#     ignore_changes = [
#       metadata[0].annotations
#     ]
#   }
# }

# No PVC for local dev - using emptyDir

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-secret"
    namespace = var.namespace
  }

  data = {
    username = var.config.username
    password = random_password.postgres_password.result
    database = var.config.database_name
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "postgres"
      "app.kubernetes.io/component" = "database"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:${var.config.version}"

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "database"
              }
            }
          }

          port {
            container_port = var.config.port
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "postgres-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "postgres"
      "app.kubernetes.io/component" = "database"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "postgres"
    }

    port {
      port        = var.config.port
      target_port = var.config.port
    }
  }
}
