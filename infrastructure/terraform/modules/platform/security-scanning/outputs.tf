output "namespace" {
  description = "Security scanning namespace"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].namespace : ""
    ) : (
    length(module.aws_security_scanning) > 0 ? module.aws_security_scanning[0].namespace : ""
  )
}

output "scanning_facilities" {
  description = "Security scanning facilities"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].scanning_facilities : {}
    ) : (
    length(module.aws_security_scanning) > 0 ? module.aws_security_scanning[0].scanning_facilities : {}
  )
}

output "argocd_project" {
  description = "ArgoCD project for security applications"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].argocd_project : null
  ) : null
}

output "useful_commands" {
  description = "Useful commands for security scanning operations"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].useful_commands : {}
  ) : {}
}
