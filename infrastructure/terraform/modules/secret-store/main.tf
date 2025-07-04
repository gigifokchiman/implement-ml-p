# Secret Store Module
# Manages secrets in Kubernetes using native Secret resources

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Create secret store namespace
resource "kubernetes_namespace" "secret_store" {
  metadata {
    name = "secret-store"
    labels = merge(var.tags, {
      "team"                        = "platform-engineering"
      "cost-center"                 = "platform"
      "environment"                 = var.environment
      "workload-type"               = "security"
      "app.kubernetes.io/name"      = "secret-store"
      "app.kubernetes.io/component" = "namespace"
    })
  }
}

# Platform secrets storage
resource "kubernetes_secret" "platform_secrets" {
  metadata {
    name      = "platform-secrets"
    namespace = kubernetes_namespace.secret_store.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "platform-secrets"
      "app.kubernetes.io/component" = "secret-store"
    })
  }

  type = "Opaque"

  data = {
    argocd_admin_password    = var.argocd_admin_password
    grafana_admin_password   = var.grafana_admin_password
    postgres_admin_password  = var.postgres_admin_password
    redis_password          = var.redis_password
    minio_access_key        = var.minio_access_key
    minio_secret_key        = var.minio_secret_key
  }
}

# Service account for secret access
resource "kubernetes_service_account" "secret_reader" {
  metadata {
    name      = "secret-reader"
    namespace = kubernetes_namespace.secret_store.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "secret-reader"
      "app.kubernetes.io/component" = "secret-store"
    })
  }
}

# Role for reading secrets
resource "kubernetes_role" "secret_reader" {
  metadata {
    name      = "secret-reader"
    namespace = kubernetes_namespace.secret_store.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "secret-reader"
      "app.kubernetes.io/component" = "secret-store"
    })
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }
}

# Role binding
resource "kubernetes_role_binding" "secret_reader" {
  metadata {
    name      = "secret-reader"
    namespace = kubernetes_namespace.secret_store.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "secret-reader"
      "app.kubernetes.io/component" = "secret-store"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.secret_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.secret_reader.metadata[0].name
    namespace = kubernetes_namespace.secret_store.metadata[0].name
  }
}

# Secret accessor script configmap
resource "kubernetes_config_map" "secret_accessor" {
  metadata {
    name      = "secret-accessor"
    namespace = kubernetes_namespace.secret_store.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "secret-accessor"
      "app.kubernetes.io/component" = "secret-store"
    })
  }

  data = {
    "get-secret.sh" = <<-EOT
      #!/bin/bash
      # Secret accessor script
      set -e
      
      SECRET_NAME="$1"
      SECRET_KEY="$2"
      NAMESPACE="${var.secret_store_namespace}"
      
      if [ -z "$SECRET_NAME" ] || [ -z "$SECRET_KEY" ]; then
        echo "Usage: $0 <secret-name> <secret-key>"
        echo "Available secrets:"
        kubectl get secrets -n $NAMESPACE --no-headers | awk '{print $1}'
        exit 1
      fi
      
      kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.$SECRET_KEY}" | base64 -d
    EOT
  }
}