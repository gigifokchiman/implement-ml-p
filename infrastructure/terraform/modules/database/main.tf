# Database module that works for both local (PostgreSQL in K8s) and cloud (RDS) environments
locals {
  is_local    = var.environment == "local"
  name_prefix = var.name_prefix

  # Generate database password if not provided
  db_password = var.database_password != null ? var.database_password : random_password.db_password[0].result
}

# Generate random password for database
resource "random_password" "db_password" {
  count   = var.database_password == null ? 1 : 0
  length  = 32
  special = true
}

# AWS Secrets Manager secret for database password (cloud environments only)
resource "aws_secretsmanager_secret" "db_password" {
  count = local.is_local ? 0 : 1

  name        = "${local.name_prefix}-database-password"
  description = "Database password for ${local.name_prefix}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count = local.is_local ? 0 : 1

  secret_id     = aws_secretsmanager_secret.db_password[0].id
  secret_string = local.db_password
}

# RDS for cloud environments
module "rds" {
  count = local.is_local ? 0 : 1

  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.name_prefix}-metadata"

  engine               = var.config.engine
  engine_version       = var.config.version
  family               = "${var.config.engine}${split(".", var.config.version)[0]}"
  major_engine_version = split(".", var.config.version)[0]
  instance_class       = var.config.instance_class

  allocated_storage     = var.config.storage_size
  max_allocated_storage = var.config.storage_size * 5

  db_name  = var.config.database_name
  username = var.config.username
  password = local.db_password

  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  multi_az            = var.config.multi_az
  storage_encrypted   = var.config.encrypted
  deletion_protection = var.deletion_protection
  skip_final_snapshot = !var.deletion_protection

  # Enhanced monitoring
  monitoring_interval    = var.enable_monitoring ? 60 : 0
  monitoring_role_name   = var.enable_monitoring ? "${local.name_prefix}-rds-monitoring" : null
  create_monitoring_role = var.enable_monitoring

  # Performance insights
  performance_insights_enabled          = var.environment == "prod"
  performance_insights_retention_period = var.environment == "prod" ? 7 : null

  tags = var.tags
}

# Kubernetes resources for local environment
resource "kubernetes_namespace" "database" {
  count = local.is_local ? 1 : 0

  metadata {
    name = "${var.namespace}-database"
    labels = {
      name                        = "${var.namespace}-database"
      "app.kubernetes.io/part-of" = var.namespace
    }
  }
}

# PostgreSQL Secret for local environment
resource "kubernetes_secret" "postgres_credentials" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "postgres-credentials"
    namespace = var.namespace
  }

  data = {
    username = var.config.username
    password = local.db_password
    database = var.config.database_name
  }

  type = "Opaque"
}

# PostgreSQL ConfigMap for local environment
resource "kubernetes_config_map" "postgres_config" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "postgres-config"
    namespace = var.namespace
  }

  data = {
    POSTGRES_DB   = var.config.database_name
    POSTGRES_USER = var.config.username
    PGDATA        = "/var/lib/postgresql/data/pgdata"
  }
}

# PostgreSQL PVC for local environment
resource "kubernetes_persistent_volume_claim" "postgres_data" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "postgres-data"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "postgresql"
      "app.kubernetes.io/component" = "database"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "${var.config.storage_size}Gi"
      }
    }

    storage_class_name = var.local_storage_class
  }
}

# PostgreSQL Deployment for local environment
resource "kubernetes_deployment" "postgres" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "postgresql"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "postgresql"
      "app.kubernetes.io/component" = "database"
      "app.kubernetes.io/part-of"   = var.namespace
      "app.kubernetes.io/version"   = var.config.version
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "postgresql"
        "app.kubernetes.io/component" = "database"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "postgresql"
          "app.kubernetes.io/component" = "database"
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
          name  = "postgresql"
          image = "postgres:${var.config.version}-alpine"

          port {
            container_port = 5432
            name           = "postgresql"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.postgres_config[0].metadata[0].name
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_credentials[0].metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.config.username, "-d", var.config.database_name]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.config.username, "-d", var.config.database_name]
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
            run_as_non_root = true
            run_as_user     = 999
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_data[0].metadata[0].name
          }
        }
      }
    }
  }
}

# PostgreSQL Service for local environment
resource "kubernetes_service" "postgres" {
  count = local.is_local ? 1 : 0

  metadata {
    name      = "postgresql"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "postgresql"
      "app.kubernetes.io/component" = "database"
      "app.kubernetes.io/part-of"   = var.namespace
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "postgresql"
      "app.kubernetes.io/component" = "database"
    }

    port {
      name        = "postgresql"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}