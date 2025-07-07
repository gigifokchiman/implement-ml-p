# Kubernetes Security Platform - Foundation Only
# Terraform manages: namespace, RBAC, protection policies
# ArgoCD manages: actual tool deployments (Trivy, Falco)

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }

  # Security-critical labels
  security_labels = merge(local.k8s_tags, {
    "security.platform/critical"   = "true"
    "security.platform/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "security-platform"
  })
}

# Security scanning namespace with enhanced protection
resource "kubernetes_namespace" "security_scanning" {
  metadata {
    name = var.name
    labels = merge(local.security_labels, {
      "app.kubernetes.io/name"             = "security-scanning"
      "app.kubernetes.io/component"        = "security"
      "workload-type"                      = "security"
      "pod-security.kubernetes.io/enforce" = "privileged" # Security tools need privileged access
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
      "argocd.argoproj.io/managed"         = "true"
    })

    annotations = {
      "security.platform/do-not-delete" = "This namespace is critical for security compliance"
      "security.platform/owner"         = "platform-security-team"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      metadata[0].annotations["kubectl.kubernetes.io/last-applied-configuration"]
    ]
  }
}


# ArgoCD project for security applications
resource "kubernetes_manifest" "security_argocd_project" {
  count = var.create_namespace_only ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "platform-security"
      namespace = "argocd"
      labels    = local.security_labels
    }
    spec = {
      description = "Security platform applications"

      sourceRepos = ["*"]

      destinations = [{
        namespace = kubernetes_namespace.security_scanning.metadata[0].name
        server    = "https://kubernetes.default.svc"
      }]

      clusterResourceWhitelist = [{
        group = "*"
        kind  = "*"
      }]

      namespaceResourceWhitelist = [{
        group = "*"
        kind  = "*"
      }]

      roles = [{
        name = "security-admin"
        policies = [
          "p, proj:platform-security:security-admin, applications, *, platform-security/*, allow"
        ]
        groups = ["platform-security-team"]
      }]
    }
  }
}

# Core scanning facilities - deployed by Terraform as platform infrastructure
# ArgoCD applications will USE these facilities for scanning

# PVC for Trivy cache - only for cloud environments with persistent storage
resource "kubernetes_persistent_volume_claim" "trivy_cache" {
  count = 0 # Disabled for local Kind - use emptyDir instead

  metadata {
    name      = "trivy-cache"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = merge(local.security_labels, {
      "app.kubernetes.io/name"      = "trivy"
      "app.kubernetes.io/component" = "cache"
    })
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

# Trivy server deployment (core scanning facility)
resource "kubernetes_deployment" "trivy_server" {
  count = var.create_namespace_only ? 1 : 0

  metadata {
    name      = "trivy-server"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = merge(local.security_labels, {
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
          "app.kubernetes.io/part-of"   = "security-scanning"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.security_scanner.metadata[0].name
        priority_class_name  = kubernetes_priority_class.security_critical.metadata[0].name

        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }

        container {
          name  = "trivy"
          image = "aquasec/trivy:0.48.3"
          args = [
            "server",
            "--listen", "0.0.0.0:4954",
            "--cache-dir", "/cache"
          ]

          port {
            container_port = 4954
            name           = "trivy-server"
          }

          env {
            name  = "TRIVY_CACHE_DIR"
            value = "/cache"
          }
          env {
            name  = "TRIVY_TIMEOUT"
            value = "10m"
          }
          env {
            name  = "TRIVY_DB_REPOSITORY"
            value = "ghcr.io/aquasecurity/trivy-db"
          }
          env {
            name  = "TMPDIR"
            value = "/cache"
          }

          volume_mount {
            name       = "cache"
            mount_path = "/cache"
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

        volume {
          name = "cache"
          empty_dir {
            # Use emptyDir for local Kind - temporary storage
          }
        }
      }
    }
  }
}

# Trivy server service
resource "kubernetes_service" "trivy_server" {
  count = var.create_namespace_only ? 1 : 0

  metadata {
    name      = "trivy-server"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = merge(local.security_labels, {
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
      port        = 4954
      target_port = 4954
      name        = "trivy-server"
    }
  }
}

# Falco ConfigMap for production environments (not Kind)
resource "kubernetes_config_map" "falco_config" {
  count = var.create_namespace_only && var.environment != "local" ? 1 : 0

  metadata {
    name      = "falco-config"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = merge(local.security_labels, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "config"
    })
  }

  data = {
    "falco.yaml" = <<-EOT
      # Falco configuration for EKS/production environments
      
      plugins:
        - name: k8saudit
          library_path: libk8saudit.so
          init_config:
            maxEventBytes: 1048576
            webhookMaxBatchSize: 12582912
          open_params: "/var/log/audit.log"
      
      load_plugins: [k8saudit]
      
      rules_file:
        - /etc/falco/falco_rules.yaml
        - /etc/falco/falco_rules.local.yaml
        - /etc/falco/k8s_audit_rules.yaml
      
      json_output: true
      json_include_output_property: true
      
      log_stderr: true
      log_syslog: false
      log_level: info
      
      priority: debug
      
      stdout_output:
        enabled: true
      
      syslog_output:
        enabled: false
      
      webserver:
        enabled: true
        listen_port: 8765
        ssl_enabled: false
      
      outputs:
        rate: 1
        max_burst: 1000
      
      syscall_event_drops:
        actions:
          - log
          - alert
        rate: .03333
        max_burst: 10
    EOT
  }
}

# Falco DaemonSet (core runtime security facility)
# 
# Deployment Logic:
# - EKS/Production: Deploys with full syscall + k8s audit monitoring
# - Kind/Local: Disabled - Falco requires kernel module access for syscalls
#               which is not available in Kind containers
# 
# For local development, security is provided by:
# - Trivy server for image scanning
# - Security admission webhook for policy enforcement
# - Audit logs are still generated for manual analysis
resource "kubernetes_daemonset" "falco" {
  count = var.create_namespace_only && var.environment != "local" ? 1 : 0

  metadata {
    name      = "falco"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = merge(local.security_labels, {
      "app.kubernetes.io/name"      = "falco"
      "app.kubernetes.io/component" = "runtime-security"
    })
  }

  spec {
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
          "app.kubernetes.io/part-of"   = "security-scanning"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.security_scanner.metadata[0].name
        priority_class_name  = kubernetes_priority_class.security_critical.metadata[0].name
        host_network         = true
        host_pid             = true

        toleration {
          effect = "NoSchedule"
          key    = "node-role.kubernetes.io/master"
        }
        toleration {
          effect = "NoSchedule"
          key    = "node-role.kubernetes.io/control-plane"
        }

        container {
          name  = "falco"
          image = "falcosecurity/falco:0.36.2"
          args = [
            "/usr/bin/falco",
            "-K", "/var/run/secrets/kubernetes.io/serviceaccount/token",
            "-k", "https://$(KUBERNETES_SERVICE_HOST)",
            "-c", "/etc/falco-custom/falco.yaml"
          ]

          env {
            name = "KUBERNETES_SERVICE_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          security_context {
            privileged = true
          }

          volume_mount {
            mount_path = "/host/var/run/docker.sock"
            name       = "docker-socket"
          }
          volume_mount {
            mount_path = "/host/dev"
            name       = "dev-fs"
            read_only  = true
          }
          volume_mount {
            mount_path = "/host/proc"
            name       = "proc-fs"
            read_only  = true
          }
          volume_mount {
            mount_path = "/etc/falco-custom"
            name       = "falco-config"
            read_only  = true
          }
          volume_mount {
            mount_path = "/var/log"
            name       = "audit-logs"
            read_only  = true
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "1024Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
          }

          port {
            container_port = 8765
            name           = "http"
          }
        }

        volume {
          name = "docker-socket"
          host_path {
            path = "/var/run/docker.sock"
          }
        }
        volume {
          name = "dev-fs"
          host_path {
            path = "/dev"
          }
        }
        volume {
          name = "proc-fs"
          host_path {
            path = "/proc"
          }
        }
        volume {
          name = "audit-logs"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "falco-config"
          config_map {
            name = kubernetes_config_map.falco_config[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Falco service
resource "kubernetes_service" "falco" {
  count = var.create_namespace_only ? 1 : 0

  metadata {
    name      = "falco"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = merge(local.security_labels, {
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
      port        = 8765
      target_port = 8765
      name        = "http"
    }
  }
}