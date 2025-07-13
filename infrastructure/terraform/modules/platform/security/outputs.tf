output "security_policies" {
  description = "Applied security policies"
  value       = module.kubernetes_security.security_policies
}

output "network_policies" {
  description = "Network policies status"
  value       = module.kubernetes_security.network_policies
}
