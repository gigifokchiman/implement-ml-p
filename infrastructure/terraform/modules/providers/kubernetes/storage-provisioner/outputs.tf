output "storage_class_name" {
  description = "Name of the default storage class"
  value       = kubernetes_storage_class.local_path.metadata[0].name
}

output "provisioner_namespace" {
  description = "Namespace where the provisioner is deployed"
  value       = kubernetes_namespace.local_path_storage.metadata[0].name
}

output "provisioner_name" {
  description = "Name of the provisioner deployment"
  value       = kubernetes_deployment.local_path_provisioner.metadata[0].name
}