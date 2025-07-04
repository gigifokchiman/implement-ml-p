# Kubernetes Security Scanning Implementation
# Uses Trivy for container image scanning and vulnerability assessment

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

# Namespace for security scanning
resource "kubernetes_namespace" "security_scanning" {
  metadata {
    name = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"             = "security-scanning"
      "app.kubernetes.io/component"        = "security"
      "workload-type"                      = "security"
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    })
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

# Trivy vulnerability database
resource "kubernetes_persistent_volume_claim" "trivy_cache" {
  count = var.config.enable_vulnerability_db ? 1 : 0

  metadata {
    name      = "trivy-cache"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "trivy"
      "app.kubernetes.io/component" = "cache"
    })
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

# Trivy server deployment
resource "kubernetes_deployment" "trivy_server" {
  count = var.config.enable_image_scanning ? 1 : 0

  metadata {
    name      = "trivy-server"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "trivy"
      "app.kubernetes.io/component" = "server"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "trivy"
        "app.kubernetes.io/component" = "server"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "trivy"
          "app.kubernetes.io/component" = "server"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }

        container {
          name  = "trivy"
          image = "aquasec/trivy:0.48.3"
          args  = ["server", "--listen", "0.0.0.0:4954", "--cache-dir", "/tmp/trivy/.cache"]

          port {
            container_port = 4954
            name           = "trivy-server"
          }

          env {
            name  = "TRIVY_CACHE_DIR"
            value = "/tmp/trivy/.cache"
          }

          env {
            name  = "TRIVY_TIMEOUT"
            value = "10m"
          }

          env {
            name  = "TRIVY_DB_REPOSITORY"
            value = "ghcr.io/aquasecurity/trivy-db"
          }

          volume_mount {
            name       = "cache"
            mount_path = "/tmp/trivy/.cache"
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 4954
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 4954
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }
        }

        dynamic "volume" {
          for_each = var.config.enable_vulnerability_db ? [1] : []
          content {
            name = "cache"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim.trivy_cache[0].metadata[0].name
            }
          }
        }

        dynamic "volume" {
          for_each = var.config.enable_vulnerability_db ? [] : [1]
          content {
            name = "cache"
            empty_dir {}
          }
        }
      }
    }
  }
}

# Trivy server service
resource "kubernetes_service" "trivy_server" {
  count = var.config.enable_image_scanning ? 1 : 0

  metadata {
    name      = "trivy-server"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "trivy"
      "app.kubernetes.io/component" = "server"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "trivy"
      "app.kubernetes.io/component" = "server"
    }

    port {
      name        = "trivy-server"
      port        = 4954
      target_port = 4954
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Trivy image scanning cronjob
resource "kubernetes_cron_job_v1" "image_scanner" {
  count = var.config.enable_image_scanning ? 1 : 0

  metadata {
    name      = "trivy-image-scanner"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "trivy"
      "app.kubernetes.io/component" = "scanner"
    })
  }

  spec {
    schedule = var.config.scan_schedule

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "trivy"
          "app.kubernetes.io/component" = "scanner"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "trivy"
              "app.kubernetes.io/component" = "scanner"
            }
          }

          spec {
            restart_policy = "OnFailure"

            security_context {
              run_as_non_root = true
              run_as_user     = 65534
              fs_group        = 65534
            }

            container {
              name    = "trivy-scanner"
              image   = "aquasec/trivy:0.48.3"
              command = ["/bin/sh"]
              args = [
                "-c",
                <<-EOT
                  # Scan common container images
                  trivy image --server http://trivy-server:4954 --severity ${var.config.severity_threshold} --format json postgres:15
                  trivy image --server http://trivy-server:4954 --severity ${var.config.severity_threshold} --format json redis:7
                  trivy image --server http://trivy-server:4954 --severity ${var.config.severity_threshold} --format json minio/minio:RELEASE.2024-01-16T16-07-38Z
                  trivy image --server http://trivy-server:4954 --severity ${var.config.severity_threshold} --format json prom/prometheus:v2.48.1
                  trivy image --server http://trivy-server:4954 --severity ${var.config.severity_threshold} --format json grafana/grafana:10.2.3
                EOT
              ]

              resources {
                limits = {
                  cpu    = "500m"
                  memory = "512Mi"
                }
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
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

# Runtime security scanning using Falco (optional)
resource "kubernetes_deployment" "falco" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  metadata {
    name      = "falco"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "falco"
        "app.kubernetes.io/component" = "runtime-security"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "falco"
          "app.kubernetes.io/component" = "runtime-security"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.falco[0].metadata[0].name

        container {
          name  = "falco"
          image = "falcosecurity/falco-no-driver:0.36.2"

          args = [
            "/usr/bin/falco",
            "--cri", "/run/containerd/containerd.sock",
            "--disable-source", "kernel",
            "--enable-source", "k8s_audit",
            "--k8s-api", "https://kubernetes.default.svc",
            "--k8s-api-cert", "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
            "--k8s-api-token", "/var/run/secrets/kubernetes.io/serviceaccount/token"
          ]

          env {
            name  = "FALCO_GRPC_ENABLED"
            value = "true"
          }

          env {
            name  = "FALCO_GRPC_BIND_ADDRESS"
            value = "0.0.0.0:5060"
          }

          env {
            name  = "FALCO_WEBSERVER_ENABLED"
            value = "true"
          }

          env {
            name  = "FALCO_WEBSERVER_LISTEN_PORT"
            value = "8765"
          }

          port {
            container_port = 5060
            name           = "grpc"
          }

          port {
            container_port = 8765
            name           = "http"
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
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

# Service account for Falco
resource "kubernetes_service_account" "falco" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  metadata {
    name      = "falco"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    })
  }
}

# Cluster role for Falco
resource "kubernetes_cluster_role" "falco" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  metadata {
    name = "falco"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    })
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "pods", "replicationcontrollers", "services", "endpoints", "events", "configmaps", "secrets", "serviceaccounts"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["get", "list", "watch"]
  }
}

# Cluster role binding for Falco
resource "kubernetes_cluster_role_binding" "falco" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  metadata {
    name = "falco"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.falco[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.falco[0].metadata[0].name
    namespace = var.name
  }
}

# Falco service
resource "kubernetes_service" "falco" {
  count = var.config.enable_runtime_scanning ? 1 : 0

  metadata {
    name      = "falco"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    }

    port {
      name        = "grpc"
      port        = 5060
      target_port = 5060
      protocol    = "TCP"
    }

    port {
      name        = "http"
      port        = 8765
      target_port = 8765
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}