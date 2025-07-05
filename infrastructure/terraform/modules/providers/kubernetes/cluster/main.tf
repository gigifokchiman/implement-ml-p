# Kind Cluster Provider
# Wraps Kind cluster for local development

terraform {
  required_providers {
    kind = {
      source  = "kind.local/gigifokchiman/kind"
      version = "0.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

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
          EOT
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
                environment = var.environment
                cluster-name = local.cluster_name
                node-role = name
              }) : "${k}=${v}"])}"
          EOT
        ]
      }
    ]
  )
}

# Local Docker Registry for Kind
resource "docker_image" "registry" {
  name = "registry:2"
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
      }
    }

  }

  depends_on = [docker_container.registry]
}

# Wait for cluster to be ready
resource "null_resource" "wait_for_cluster" {
  depends_on = [kind_cluster.main]
  
  provisioner "local-exec" {
    command = "kubectl --context kind-${local.cluster_name} wait --for=condition=Ready nodes --all --timeout=300s"
  }
}