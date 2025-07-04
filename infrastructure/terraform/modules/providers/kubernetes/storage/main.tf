# Kubernetes MinIO implementation

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

resource "kubernetes_namespace" "storage" {
  metadata {
    name = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "storage"
      "app.kubernetes.io/component" = "storage"
      "workload-type"               = "storage"
    })
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

resource "random_password" "minio_admin" {
  length  = 16
  special = false
}

resource "kubernetes_secret" "minio" {
  metadata {
    name      = "minio-secret"
    namespace = var.name
  }

  data = {
    username = "admin"
    password = random_password.minio_admin.result
  }
}

# No PVC for local dev - using emptyDir

resource "kubernetes_deployment" "minio" {
  metadata {
    name      = "minio"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "minio"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "minio"
        }
      }

      spec {
        container {
          name  = "minio"
          image = "minio/minio:latest"

          command = ["minio", "server", "/data"]

          env {
            name = "MINIO_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "MINIO_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio.metadata[0].name
                key  = "password"
              }
            }
          }

          port {
            container_port = 9000
          }

          volume_mount {
            name       = "minio-storage"
            mount_path = "/data"
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
          name = "minio-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "minio" {
  metadata {
    name      = "minio"
    namespace = var.name
    labels = {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "minio"
    }

    port {
      port        = 9000
      target_port = 9000
    }
  }
}

# Create buckets using kubernetes job
resource "kubernetes_job" "create_buckets" {
  count = length(var.config.buckets)

  metadata {
    name      = "create-bucket-${var.config.buckets[count.index].name}"
    namespace = var.name
  }

  spec {
    template {
      metadata {}

      spec {
        restart_policy = "Never"

        container {
          name  = "mc"
          image = "minio/mc:latest"

          command = [
            "sh", "-c",
            "mc alias set minio http://minio:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY && mc mb minio/${var.config.buckets[count.index].name} --ignore-existing"
          ]

          env {
            name = "MINIO_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "MINIO_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio.metadata[0].name
                key  = "password"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.minio]
}