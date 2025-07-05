# Kind Cluster Provider Outputs

output "cluster_name" {
  description = "Kind cluster name"
  value       = kind_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kind cluster endpoint"
  value       = kind_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = kind_cluster.main.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value = {
    host                   = kind_cluster.main.endpoint
    cluster_ca_certificate = base64decode(kind_cluster.main.cluster_ca_certificate)
    client_certificate     = base64decode(kind_cluster.main.client_certificate)
    client_key             = base64decode(kind_cluster.main.client_key)
  }
  sensitive = true
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = kind_cluster.main.kubeconfig_path
}

output "local_registry_url" {
  description = "Local Docker registry URL"
  value       = "localhost:5001"
}

output "registry_container_name" {
  description = "Docker registry container name"
  value       = docker_container.registry.name
}

output "port_mappings" {
  description = "Port mappings for accessing services"
  value = {
    http  = "http://localhost:${var.port_mappings[0].host_port}"
    https = "https://localhost:${var.port_mappings[1].host_port}"
  }
}

output "useful_commands" {
  description = "Useful commands for this cluster"
  value = {
    kubectl_context      = "kubectl config use-context kind-${kind_cluster.main.name}"
    get_nodes           = "kubectl --context kind-${kind_cluster.main.name} get nodes -o wide"
    port_forward_example = "kubectl --context kind-${kind_cluster.main.name} port-forward -n namespace svc/service 8080:80"
    registry_catalog    = "curl http://localhost:5001/v2/_catalog"
    push_image_example  = "docker tag myimage:latest localhost:5001/myimage:latest && docker push localhost:5001/myimage:latest"
  }
}