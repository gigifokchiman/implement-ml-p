# Kubernetes Audit Logging Provider Outputs

output "namespace" {
  description = "Audit logging namespace"
  value       = kubernetes_namespace.audit_logging.metadata[0].name
}

output "config_map_names" {
  description = "Names of created config maps"
  value = merge(
    {
      audit_policy = kubernetes_config_map.audit_policy.metadata[0].name
    },
    var.config.enable_log_collection ? {
      log_collector = kubernetes_config_map.audit_log_collector[0].metadata[0].name
    } : {}
  )
}

output "service_account_name" {
  description = "Service account name for log collection"
  value       = var.config.enable_log_collection ? kubernetes_service_account.log_collector[0].metadata[0].name : null
}

output "daemonset_name" {
  description = "DaemonSet name for log collection"
  value       = var.config.enable_log_collection ? kubernetes_daemonset.log_collector[0].metadata[0].name : null
}

output "cluster_role_name" {
  description = "ClusterRole name for log collection"
  value       = var.config.enable_log_collection ? kubernetes_cluster_role.log_collector[0].metadata[0].name : null
}

output "audit_policy_path" {
  description = "Path to the audit policy file"
  value       = "${path.module}/audit-policy.yaml"
}