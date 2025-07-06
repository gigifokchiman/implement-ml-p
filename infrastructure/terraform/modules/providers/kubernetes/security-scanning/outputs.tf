output "namespace" {
  description = "Security scanning namespace"
  value       = kubernetes_namespace.security_scanning.metadata[0].name
}

output "argocd_project" {
  description = "ArgoCD project for security applications"
  value       = var.create_namespace_only ? "platform-security" : null
}

output "scanning_facilities" {
  description = "Core scanning facilities deployed"
  value = {
    trivy_server_endpoint = var.create_namespace_only ? "http://trivy-server.${kubernetes_namespace.security_scanning.metadata[0].name}.svc.cluster.local:4954" : null
    falco_endpoint       = var.create_namespace_only ? "http://falco.${kubernetes_namespace.security_scanning.metadata[0].name}.svc.cluster.local:8765" : null
    namespace           = kubernetes_namespace.security_scanning.metadata[0].name
    facilities_ready    = var.create_namespace_only
  }
}

output "useful_commands" {
  description = "Useful commands for security infrastructure"
  value = {
    check_namespace         = "kubectl get ns ${kubernetes_namespace.security_scanning.metadata[0].name}"
    check_argocd_project    = var.create_namespace_only ? "kubectl get appproject -n argocd platform-security" : "N/A"
    check_cicd_namespace    = length(kubernetes_namespace.cicd_system) > 0 ? "kubectl get ns ${kubernetes_namespace.cicd_system[0].metadata[0].name}" : "N/A"
    get_cicd_token          = length(kubernetes_service_account.cicd_deployer) > 0 ? "kubectl create token ${kubernetes_service_account.cicd_deployer[0].metadata[0].name} -n ${kubernetes_namespace.cicd_system[0].metadata[0].name}" : "N/A"
    next_step               = "Deploy security tools via ArgoCD: kubectl apply -f kubernetes/base/gitops/applications/security-scanning.yaml"
  }
}