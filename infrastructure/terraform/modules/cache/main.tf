# Cache module that works for both local (Redis in K8s) and cloud (ElastiCache) environments
locals {
  is_local    = var.environment == "local"
  name_prefix = var.name_prefix
}

# ElastiCache for cloud environments
resource "aws_elasticache_subnet_group" "redis" {
  count = local.is_local ? 0 : 1

  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

module "elasticache" {
  count = local.is_local ? 0 : 1

  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  replication_group_id = "${local.name_prefix}-cache"

  engine          = var.config.engine
  node_type       = var.config.node_type
  num_cache_nodes = var.config.num_nodes

  subnet_group_name  = aws_elasticache_subnet_group.redis[0].name
  security_group_ids = var.security_group_ids

  # Security
  at_rest_encryption_enabled = var.config.encrypted
  transit_encryption_enabled = var.config.encrypted
  auth_token                 = var.config.encrypted ? random_password.redis_auth[0].result : null

  # Backup
  snapshot_retention_limit = var.backup_retention_days
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  tags = var.tags
}

# Generate auth token for encrypted Redis
resource "random_password" "redis_auth" {
  count   = local.is_local || !var.config.encrypted ? 0 : 1
  length  = 32
  special = false # ElastiCache doesn't support all special characters
}

# Kubernetes resources for local environment
resource "kubernetes_config_map" "redis_config" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "redis-config"
    namespace = var.namespace
  }

  data = {
    "redis.conf" = <<EOF
# Redis configuration for ML Platform
port 6379
bind 0.0.0.0
protected-mode yes

# Memory management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000

# Logging
loglevel notice

# Security
requirepass ${random_password.redis_password[0].result}
EOF
  }
}

# Redis password for local environment
resource "random_password" "redis_password" {
  count   = local.is_local ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "redis_credentials" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "redis-credentials"
    namespace = var.namespace
  }

  data = {
    password = random_password.redis_password[0].result
  }

  type = "Opaque"
}

# Redis PVC for local environment
resource "kubernetes_persistent_volume_claim" "redis_data" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "redis-data"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "5Gi"
      }
    }

    storage_class_name = var.local_storage_class
  }
}

# Redis Deployment for local environment
resource "kubernetes_deployment" "redis" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "redis"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
      "app.kubernetes.io/part-of"   = var.namespace
      "app.kubernetes.io/version"   = var.config.version
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "redis"
        "app.kubernetes.io/component" = "cache"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "redis"
          "app.kubernetes.io/component" = "cache"
          "app.kubernetes.io/part-of"   = var.namespace
        }
      }

      spec {
        security_context {
          run_as_user  = 999
          run_as_group = 999
          fs_group     = 999
        }

        container {
          name  = "redis"
          image = "redis:${var.config.version}-alpine"

          port {
            container_port = 6379
            name           = "redis"
          }

          command = ["redis-server", "/etc/redis/redis.conf"]

          volume_mount {
            name       = "redis-config"
            mount_path = "/etc/redis"
          }

          volume_mount {
            name       = "redis-data"
            mount_path = "/data"
          }

          liveness_probe {
            exec {
              command = ["redis-cli", "--no-auth-warning", "-a", random_password.redis_password[0].result, "ping"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["redis-cli", "--no-auth-warning", "-a", random_password.redis_password[0].result, "ping"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = var.development_mode ? "50m" : "100m"
              memory = var.development_mode ? "64Mi" : "128Mi"
            }
            limits = {
              cpu    = var.development_mode ? "200m" : "500m"
              memory = var.development_mode ? "128Mi" : "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            run_as_non_root = true
            run_as_user     = 999
          }
        }

        volume {
          name = "redis-config"
          config_map {
            name = kubernetes_config_map.redis_config[0].metadata[0].name
          }
        }

        volume {
          name = "redis-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.redis_data[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Redis Service for local environment
resource "kubernetes_service" "redis" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "redis"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "cache"
    }

    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}