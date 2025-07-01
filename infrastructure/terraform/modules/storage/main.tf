# Storage module that works for both local (MinIO in K8s) and cloud (S3) environments
locals {
  is_local    = var.environment == "local"
  name_prefix = var.name_prefix
}

# S3 buckets for cloud environments
resource "aws_s3_bucket" "buckets" {
  for_each = local.is_local ? {} : { for bucket in var.config.buckets : bucket.name => bucket }

  bucket = "${local.name_prefix}-${each.value.name}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = local.is_local ? {} : aws_s3_bucket.buckets

  bucket = each.value.id
  versioning_configuration {
    status = var.config.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.is_local ? {} : aws_s3_bucket.buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.is_local ? {} : aws_s3_bucket.buckets

  bucket = each.value.id

  block_public_acls       = !var.config.buckets[index(var.config.buckets.*.name, each.key)].public
  block_public_policy     = !var.config.buckets[index(var.config.buckets.*.name, each.key)].public
  ignore_public_acls      = !var.config.buckets[index(var.config.buckets.*.name, each.key)].public
  restrict_public_buckets = !var.config.buckets[index(var.config.buckets.*.name, each.key)].public
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  for_each = local.is_local || !var.config.lifecycle_enabled ? {} : aws_s3_bucket.buckets

  bucket = each.value.id

  rule {
    id     = "ml_platform_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Delete old versions after 365 days
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# MinIO for local environment
resource "random_password" "minio_root_password" {
  count   = local.is_local ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "minio_credentials" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "minio-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  data = {
    root-user     = base64encode("admin")
    root-password = base64encode(random_password.minio_root_password[0].result)
    access-key    = base64encode("admin")
    secret-key    = base64encode(random_password.minio_root_password[0].result)
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim" "minio_data" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "minio-data"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "20Gi"
      }
    }

    storage_class_name = var.local_storage_class
  }
}

resource "kubernetes_service" "minio" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "minio"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
    }

    port {
      name        = "api"
      port        = 9000
      target_port = 9000
      protocol    = "TCP"
    }

    port {
      name        = "console"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "minio" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "minio"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "minio"
      "app.kubernetes.io/component" = "storage"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "minio"
        "app.kubernetes.io/component" = "storage"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "minio"
          "app.kubernetes.io/component" = "storage"
          "app.kubernetes.io/part-of"   = var.namespace
        }
      }

      spec {
        security_context {
          run_as_user  = 1001
          run_as_group = 1001
          fs_group     = 1001
        }

        container {
          name  = "minio"
          image = "bitnami/minio:2024.8.17"

          port {
            container_port = 9000
            name           = "api"
          }

          port {
            container_port = 9001
            name           = "console"
          }

          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials[0].metadata[0].name
                key  = "root-user"
              }
            }
          }

          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials[0].metadata[0].name
                key  = "root-password"
              }
            }
          }

          env {
            name  = "MINIO_API_PORT_NUMBER"
            value = "9000"
          }

          env {
            name  = "MINIO_CONSOLE_PORT_NUMBER"
            value = "9001"
          }

          env {
            name  = "MINIO_DATA_DIR"
            value = "/data"
          }

          env {
            name  = "MINIO_BROWSER"
            value = "on"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          liveness_probe {
            http_get {
              path = "/minio/health/live"
              port = "api"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/minio/health/ready"
              port = "api"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = var.development_mode ? "100m" : "250m"
              memory = var.development_mode ? "128Mi" : "256Mi"
            }
            limits = {
              cpu    = var.development_mode ? "500m" : "1000m"
              memory = var.development_mode ? "256Mi" : "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1001
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minio_data[0].metadata[0].name
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

# Create buckets in MinIO using a Job
resource "kubernetes_job" "minio_bucket_setup" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "minio-bucket-setup"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "minio-setup"
          "app.kubernetes.io/component" = "setup"
          "app.kubernetes.io/part-of"   = var.namespace
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "mc"
          image = "minio/mc:latest"

          command = ["/bin/sh"]
          args = [
            "-c",
            <<EOF
mc alias set local http://minio.${var.namespace}.svc.cluster.local:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
${join("\n", [for bucket in var.config.buckets : "mc mb local/${bucket.name} || true"])}
EOF
          ]

          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials[0].metadata[0].name
                key  = "root-user"
              }
            }
          }

          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials[0].metadata[0].name
                key  = "root-password"
              }
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            run_as_non_root = true
            run_as_user     = 1001
          }
        }
      }
    }

    backoff_limit = 3
  }

  depends_on = [
    kubernetes_deployment.minio,
    kubernetes_service.minio
  ]
}