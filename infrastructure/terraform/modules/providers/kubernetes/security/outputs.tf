output "security_policies" {
  description = "Applied security policies"
  value = {
    pod_security_enabled     = var.config.enable_pod_security
    pod_security_standard    = var.config.pod_security_standard
    network_policies_enabled = var.config.enable_network_policies
    secured_namespaces       = var.namespaces
  }
}

output "network_policies" {
  description = "Network policies status"
  value = {
    total_policies    = var.config.enable_network_policies ? length(var.namespaces) + 4 : 0
    deny_all_policies = var.config.enable_network_policies ? length(var.namespaces) : 0
    service_policies  = var.config.enable_network_policies ? 4 : 0
  }
}