# AWS KMS Provider Outputs

output "key_id" {
  description = "KMS key ID"
  value       = module.kms.key_id
}

output "key_arn" {
  description = "KMS key ARN"
  value       = module.kms.key_arn
}

output "aliases" {
  description = "KMS key aliases"
  value       = module.kms.aliases
}

output "key_policy" {
  description = "KMS key policy"
  value       = module.kms.key_policy
}

output "external_key_expiration_model" {
  description = "External key expiration model"
  value       = module.kms.external_key_expiration_model
}

output "external_key_state" {
  description = "External key state"
  value       = module.kms.external_key_state
}

output "external_key_usage" {
  description = "External key usage"
  value       = module.kms.external_key_usage
}
