# Kind Cluster Provider
# Wraps Kind cluster for local development


locals {
  cluster_name = "${var.name}-${var.environment}"

  # Convert node groups to Kind node configuration
  kind_nodes = concat(
    [
      {
        role = "control-plane"
        kubeadm_config_patches = [
          <<-EOT
          kind: InitConfiguration
          nodeRegistration:
            kubeletExtraArgs:
              node-labels: "ingress-ready=true,environment=${var.environment},cluster-name=${local.cluster_name},node-role=control-plane"
            taints:
            - key: node-role.kubernetes.io/control-plane
              effect: NoSchedule
          ---
          kind: ClusterConfiguration
          scheduler:
            extraArgs:
              bind-address: "0.0.0.0"
          controllerManager:
            extraArgs:
              bind-address: "0.0.0.0"
          apiServer:
            extraArgs:
              audit-log-path: /var/log/audit.log
              audit-policy-file: /etc/kubernetes/audit-policy.yaml
              audit-log-maxage: "7"
              audit-log-maxbackup: "3"
              audit-log-maxsize: "100"
            extraVolumes:
            - name: audit-policy
              hostPath: /etc/kubernetes/audit-policy.yaml
              mountPath: /etc/kubernetes/audit-policy.yaml
              readOnly: true
              pathType: File
          EOT
        ]

        # Audit logging mounts
        extra_mounts = [
          {
            host_path      = "/tmp/audit-logs"
            container_path = "/var/log"
          },
          {
            host_path      = "/tmp/audit-policy.yaml"
            container_path = "/etc/kubernetes/audit-policy.yaml"
            readonly       = true
          }
        ]
      }
    ],
    [
      for name, config in var.node_groups : {
        role = "worker"
        kubeadm_config_patches = [
          <<-EOT
          kind: JoinConfiguration
          nodeRegistration:
            kubeletExtraArgs:
              node-labels: "${join(",", [for k, v in merge(config.labels, {
          environment  = var.environment
          cluster-name = local.cluster_name
          node-role    = name
}) : "${k}=${v}"])}"
          EOT
]
}
]
)
}

# Create audit logs directory
resource "null_resource" "audit_logs_dir" {
  provisioner "local-exec" {
    command = "mkdir -p /tmp/audit-logs"
  }
}

# Create audit policy file
resource "local_file" "audit_policy" {
  filename = "/tmp/audit-policy.yaml"
  content = yamlencode({
    apiVersion = "audit.k8s.io/v1"
    kind       = "Policy"
    rules = [
      {
        level      = "RequestResponse"
        namespaces = ["kube-system", "argocd", "secret-store"]
        resources = [
          {
            group     = ""
            resources = ["secrets", "configmaps", "serviceaccounts"]
          },
          {
            group     = "rbac.authorization.k8s.io"
            resources = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
          }
        ]
      },
      {
        level      = "Request"
        namespaces = ["app-ml-team", "app-data-team", "app-core-team"]
        resources = [
          {
            group     = ""
            resources = ["pods", "services", "persistentvolumeclaims"]
          },
          {
            group     = "apps"
            resources = ["deployments", "statefulsets"]
          }
        ]
      },
      {
        level      = "RequestResponse"
        namespaces = ["data-platform-monitoring", "app-ml-team", "app-data-team", "app-core-team"]
        verbs      = ["create", "update", "patch", "delete"]
        resources = [
          {
            group     = ""
            resources = ["pods", "services", "persistentvolumeclaims", "configmaps"]
          }
        ]
      },
      {
        level = "RequestResponse"
        resources = [
          {
            group     = "cert-manager.io"
            resources = ["certificates", "issuers", "clusterissuers"]
          },
          {
            group     = "networking.k8s.io"
            resources = ["networkpolicies"]
          }
        ]
      },
      {
        level      = "Request"
        namespaces = ["argocd"]
        resources = [
          {
            group     = "argoproj.io"
            resources = ["applications", "appprojects"]
          }
        ]
      },
      {
        level = "None"
        verbs = ["get", "list", "watch"]
        resources = [
          {
            group     = ""
            resources = ["events", "nodes", "nodes/status", "pods/log", "pods/status"]
          }
        ]
      },
      {
        level      = "Metadata"
        omitStages = ["RequestReceived"]
      }
    ]
  })
}

# Local Docker Registry for Kind
resource "docker_image" "registry" {
  name         = "registry:2"
  keep_locally = true
}

resource "docker_container" "registry" {
  name  = "${local.cluster_name}-registry"
  image = docker_image.registry.image_id

  ports {
    internal = 5000
    external = 5001
  }

  restart = "unless-stopped"

  networks_advanced {
    name = "kind"
  }

  lifecycle {
    ignore_changes = [networks_advanced]
  }
}

# Kind Cluster
resource "kind_cluster" "main" {
  name           = local.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    dynamic "node" {
      for_each = local.kind_nodes
      content {
        role = node.value.role

        kubeadm_config_patches = node.value.kubeadm_config_patches

        # Only add port mappings to control plane
        dynamic "extra_port_mappings" {
          for_each = node.value.role == "control-plane" ? var.port_mappings : []
          content {
            container_port = extra_port_mappings.value.container_port
            host_port      = extra_port_mappings.value.host_port
            protocol       = extra_port_mappings.value.protocol
          }
        }

        # Add extra mounts if present
        dynamic "extra_mounts" {
          for_each = lookup(node.value, "extra_mounts", [])
          content {
            host_path       = extra_mounts.value.host_path
            container_path  = extra_mounts.value.container_path
            readonly        = lookup(extra_mounts.value, "readonly", false)
            selinux_relabel = lookup(extra_mounts.value, "selinux_relabel", false)
            propagation     = lookup(extra_mounts.value, "propagation", "None")
          }
        }
      }
    }

  }

  depends_on = [docker_container.registry, local_file.audit_policy, null_resource.audit_logs_dir]
}

# Wait for cluster to be ready
resource "null_resource" "wait_for_cluster" {
  depends_on = [kind_cluster.main]

  provisioner "local-exec" {
    command = "kubectl --context kind-${local.cluster_name} wait --for=condition=Ready nodes --all --timeout=300s"
  }
}
