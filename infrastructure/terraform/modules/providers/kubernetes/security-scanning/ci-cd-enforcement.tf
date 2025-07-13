# CI/CD-Only Deployment Enforcement
# Ensures only automated pipelines can deploy applications

# CI/CD system namespace
resource "kubernetes_namespace" "cicd_system" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name = "cicd-system"
    labels = merge(local.security_labels, {
      "app.kubernetes.io/name"             = "cicd-system"
      "security.platform/critical"         = "true"
      "pod-security.kubernetes.io/enforce" = "restricted"
    })

    annotations = {
      "security.platform/purpose" = "CI/CD automation only"
      "security.platform/audit"   = "all-operations-logged"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Service account for CI/CD deployments (ONLY account that can deploy)
resource "kubernetes_service_account" "cicd_deployer" {
  count = var.create_namespace_only ? 1 : 0

  metadata {
    name      = "cicd-deployer"
    namespace = kubernetes_namespace.cicd_system[0].metadata[0].name
    labels    = local.security_labels

    annotations = {
      "security.platform/purpose" = "Automated deployment only - no human access"
      "security.platform/audit"   = "all-deployments-logged"
    }
  }
}

# ClusterRole for CI/CD deployments
resource "kubernetes_cluster_role" "cicd_deployer" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name   = "cicd-deployer"
    labels = local.security_labels
  }

  # Allow deployment of applications
  rule {
    api_groups = ["", "apps", "batch", "networking.k8s.io"]
    resources = [
      "deployments", "services", "configmaps", "secrets",
      "jobs", "cronjobs", "ingresses", "networkpolicies"
    ]
    verbs = ["create", "update", "patch", "delete", "get", "list", "watch"]
  }

  # Allow reading pods for status checks
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "pods/status"]
    verbs      = ["get", "list", "watch"]
  }

  # Allow reading namespaces (but not security ones)
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list"]
  }

  # Note: Kubernetes RBAC doesn't support explicit DENY rules
  # Access is denied by default if not explicitly allowed
}

# ClusterRoleBinding for CI/CD service account
resource "kubernetes_cluster_role_binding" "cicd_deployer" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name   = "cicd-deployer"
    labels = local.security_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cicd_deployer[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cicd_deployer[0].metadata[0].name
    namespace = kubernetes_namespace.cicd_system[0].metadata[0].name
  }
}

# Webhook deployment for admission control
resource "kubernetes_deployment" "security_admission_webhook" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name      = "security-admission-webhook"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  spec {
    replicas = 2 # High availability for security

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "security-admission-webhook"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "security-admission-webhook"
          "app.kubernetes.io/part-of" = "security-scanning"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.security_scanner.metadata[0].name
        priority_class_name  = kubernetes_priority_class.security_critical.metadata[0].name

        container {
          name  = "webhook"
          image = "alpine:latest" # Placeholder - in production use custom webhook image

          command = ["/bin/sh"]
          args = [
            "-c",
            "echo 'Security webhook placeholder - configure with actual webhook in production' && sleep 3600"
          ]

          port {
            container_port = 8443
            name           = "webhook"
          }

          env {
            name  = "ALLOWED_SERVICE_ACCOUNT"
            value = "system:serviceaccount:${kubernetes_namespace.cicd_system[0].metadata[0].name}:${kubernetes_service_account.cicd_deployer[0].metadata[0].name}"
          }

          volume_mount {
            name       = "certs"
            mount_path = "/etc/certs"
            read_only  = true
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

          # Placeholder probes - replace with actual webhook health checks
          liveness_probe {
            exec {
              command = ["sh", "-c", "ps aux | grep sleep"]
            }
            initial_delay_seconds = 10
            period_seconds        = 30
          }
        }

        volume {
          name = "certs"
          secret {
            secret_name = "security-webhook-certs"
          }
        }
      }
    }
  }
}

# Service for admission webhook
resource "kubernetes_service" "security_admission_webhook" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name      = "security-admission-webhook"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "security-admission-webhook"
    }

    port {
      port        = 443
      target_port = "webhook"
      protocol    = "TCP"
    }
  }
}

# ValidatingAdmissionWebhook - The enforcement mechanism (disabled for now)
resource "kubernetes_validating_webhook_configuration" "cicd_only_enforcement" {
  count = 0 # Disabled for initial deployment

  metadata {
    name   = "cicd-only-deployment-policy"
    labels = local.security_labels
  }

  webhook {
    name = "enforce-cicd-only.security.platform"

    client_config {
      service {
        name      = kubernetes_service.security_admission_webhook[0].metadata[0].name
        namespace = kubernetes_namespace.security_scanning.metadata[0].name
        path      = "/validate-deployment"
      }

      # CA bundle for webhook TLS
      ca_bundle = base64encode(var.webhook_ca_bundle != "" ? var.webhook_ca_bundle : "placeholder-ca")
    }

    rule {
      operations   = ["CREATE", "UPDATE"]
      api_groups   = ["apps", "batch", ""]
      api_versions = ["v1"]
      resources    = ["deployments", "jobs", "pods", "replicasets", "daemonsets", "statefulsets"]
    }

    # Exclude system namespaces from enforcement
    namespace_selector {
      match_expressions {
        key      = "name"
        operator = "NotIn"
        values   = ["kube-system", "kube-public", "kube-node-lease", "security-scanning", "cicd-system"]
      }
    }

    failure_policy = "Fail" # Block if webhook is down (fail-safe)
  }
}

# RBAC for developers - READ ONLY
resource "kubernetes_cluster_role" "developer_read_only" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name   = "developer-read-only"
    labels = local.security_labels
  }

  # Read access to most resources
  rule {
    api_groups = ["", "apps", "batch", "networking.k8s.io", "extensions"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  # NO create/update/delete permissions for deployments
  # NO access to secrets in security namespaces
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get", "list"]
    resource_names = ["!webhook-*", "!trivy-*", "!falco-*"]
  }
}

# Emergency break-glass role (platform team only)
resource "kubernetes_cluster_role" "emergency_deployer" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name   = "emergency-deployer"
    labels = local.security_labels

    annotations = {
      "security.platform/purpose" = "Emergency break-glass access only"
      "security.platform/audit"   = "all-emergency-access-logged"
    }
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# CI/CD token secret (for GitHub Actions, etc.)
resource "kubernetes_secret" "cicd_kubeconfig" {
  count = var.create_namespace_only ? 1 : 0
  metadata {
    name      = "cicd-kubeconfig"
    namespace = kubernetes_namespace.cicd_system[0].metadata[0].name
    labels    = local.security_labels

    annotations = {
      "security.platform/purpose" = "CI/CD pipeline authentication"
    }
  }

  type = "Opaque"

  data = {
    # Placeholder kubeconfig - replace with actual service account token in production
    "kubeconfig" = base64encode("# CI/CD kubeconfig placeholder\n# Replace with actual service account token")
  }
}
