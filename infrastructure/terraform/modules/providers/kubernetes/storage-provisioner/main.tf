# Local Path Provisioner for Kind clusters
# This replaces the manual kubectl setup


locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

# Create namespace for local-path-storage
resource "kubernetes_namespace" "local_path_storage" {
  metadata {
    name = "local-path-storage"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "local-path-storage"
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

# ServiceAccount for local-path-provisioner
resource "kubernetes_service_account" "local_path_provisioner" {
  metadata {
    name      = "local-path-provisioner-service-account"
    namespace = kubernetes_namespace.local_path_storage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

# ClusterRole for local-path-provisioner
resource "kubernetes_cluster_role" "local_path_provisioner" {
  metadata {
    name = "local-path-provisioner-role"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "persistentvolumeclaims", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["endpoints", "persistentvolumes", "pods"]
    verbs      = ["*"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for local-path-provisioner
resource "kubernetes_cluster_role_binding" "local_path_provisioner" {
  metadata {
    name = "local-path-provisioner-bind"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.local_path_provisioner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.local_path_provisioner.metadata[0].name
    namespace = kubernetes_namespace.local_path_storage.metadata[0].name
  }
}

# ConfigMap for local-path-provisioner
resource "kubernetes_config_map" "local_path_config" {
  metadata {
    name      = "local-path-config"
    namespace = kubernetes_namespace.local_path_storage.metadata[0].name
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }

  data = {
    "config.json" = jsonencode({
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["/opt/local-path-provisioner"]
        }
      ]
    })
    "setup"    = ""
    "teardown" = ""
    "helperPod" = jsonencode({
      yaml = <<-EOT
apiVersion: v1
kind: Pod
metadata:
  name: helper-pod
spec:
  containers:
  - name: helper-pod
    image: busybox
    imagePullPolicy: IfNotPresent
EOT
    })
  }
}

# Deployment for local-path-provisioner
resource "kubernetes_deployment" "local_path_provisioner" {
  metadata {
    name      = "local-path-provisioner"
    namespace = kubernetes_namespace.local_path_storage.metadata[0].name
    labels = {
      app = "local-path-provisioner"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "local-path-provisioner"
      }
    }

    template {
      metadata {
        labels = {
          app = "local-path-provisioner"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.local_path_provisioner.metadata[0].name

        container {
          name  = "local-path-provisioner"
          image = "rancher/local-path-provisioner:v0.0.24"

          command = ["local-path-provisioner"]
          args = [
            "--debug",
            "start",
            "--config", "/etc/config/config.json"
          ]

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/config/"
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          image_pull_policy = "IfNotPresent"
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.local_path_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_cluster_role_binding.local_path_provisioner,
    kubernetes_config_map.local_path_config
  ]
}

# Wait for deployment to be ready
resource "time_sleep" "wait_for_provisioner" {
  depends_on = [kubernetes_deployment.local_path_provisioner]

  create_duration = "30s"
}

# Remove default Kind storage class (if it exists)
resource "kubernetes_annotations" "remove_default_storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "standard"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [time_sleep.wait_for_provisioner]

  lifecycle {
    ignore_changes = all
  }
}

# Create our custom StorageClass
resource "kubernetes_storage_class" "local_path" {
  metadata {
    name = "standard"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "local-path-storage"
      "app.kubernetes.io/component" = "storage"
    })
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }

  storage_provisioner    = "rancher.io/local-path"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  depends_on = [
    kubernetes_deployment.local_path_provisioner,
    time_sleep.wait_for_provisioner
  ]
}
