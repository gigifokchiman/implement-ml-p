# Kubernetes Backup Implementation using Velero

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

# Velero namespace
resource "kubernetes_namespace" "velero" {
  metadata {
    name = "velero"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "velero"
      "app.kubernetes.io/component" = "backup"
    })
  }
}

# Velero backup using Helm
resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = "5.0.2"
  namespace  = kubernetes_namespace.velero.metadata[0].name

  values = [
    yamlencode({
      configuration = {
        backupStorageLocation = [{
          name     = "default"
          provider = "fs"
          bucket   = "velero-backups"
          config = {
            path = "/mnt/velero-backups"
          }
        }]
        volumeSnapshotLocation = [{
          name     = "default"
          provider = "fs"
          config   = {}
        }]
      }

      deployNodeAgent = true

      schedules = {
        "database-backup" = {
          disabled = false
          schedule = var.config.backup_schedule
          template = {
            ttl                = "${var.config.retention_days * 24}h"
            includedNamespaces = ["database"]
            snapshotVolumes    = true
          }
        }
        "storage-backup" = {
          disabled = false
          schedule = var.config.backup_schedule
          template = {
            ttl                = "${var.config.retention_days * 24}h"
            includedNamespaces = ["storage"]
            snapshotVolumes    = true
          }
        }
        "cache-backup" = {
          disabled = false
          schedule = var.config.backup_schedule
          template = {
            ttl                = "${var.config.retention_days * 24}h"
            includedNamespaces = ["cache"]
            snapshotVolumes    = true
          }
        }
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      commonLabels = merge(local.k8s_tags, {
        "app.kubernetes.io/managed-by" = "terraform"
      })
    })
  ]

  depends_on = [kubernetes_namespace.velero]
}

# Backup storage PVC
resource "kubernetes_persistent_volume_claim" "backup_storage" {
  metadata {
    name      = "velero-backup-storage"
    namespace = kubernetes_namespace.velero.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
}