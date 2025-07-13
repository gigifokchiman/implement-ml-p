output "validation_results" {
  description = "Results of interface contract validation"
  value       = local.validation_results
}

output "cluster_validation_passed" {
  description = "Whether cluster interface validation passed"
  value       = local.validation_results.cluster_valid
}

output "security_validation_passed" {
  description = "Whether security interface validation passed"
  value       = local.validation_results.security_valid
}

output "provider_validation_passed" {
  description = "Whether provider config validation passed"
  value       = local.validation_results.provider_valid
}
