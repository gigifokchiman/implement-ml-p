# Audit Logging Module Outputs

output "audit_logging_namespace" {
  description = "Name of the audit logging namespace"
  value       = kubernetes_namespace.audit_logging.metadata[0].name
}

output "audit_policy_configmap" {
  description = "Name of the audit policy ConfigMap"
  value       = kubernetes_config_map.audit_policy.metadata[0].name
}

output "setup_instructions" {
  description = "Instructions for enabling audit logging"
  value = <<-EOF
    Audit policy created in ConfigMap: ${kubernetes_config_map.audit_policy.metadata[0].name}
    
    To enable audit logging:
    1. Recreate cluster: make clean-tf-local && make deploy-tf-local
    2. View logs: make audit-logs
    3. Follow logs: make audit-logs-follow
  EOF
}