# AWS Secrets Manager Provider Outputs

output "secrets" {
  description = "Map of secrets created"
  value       = { for name, secret_module in module.secrets_manager : name => secret_module.secret }
  sensitive   = true
}

output "secret_arns" {
  description = "ARNs of the secrets"
  value       = { for name, secret_module in module.secrets_manager : name => secret_module.secret_arn }
}

output "secret_names" {
  description = "Names of the secrets"
  value       = { for name, secret_module in module.secrets_manager : name => secret_module.secret_name }
}

output "secret_versions" {
  description = "Versions of the secrets"
  value       = { for name, secret_module in module.secrets_manager : name => secret_module.secret_version_id }
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = var.enable_rotation_lambda ? aws_lambda_function.rotation[0].arn : null
}

output "rotation_lambda_function_name" {
  description = "Name of the rotation Lambda function"
  value       = var.enable_rotation_lambda ? aws_lambda_function.rotation[0].function_name : null
}

output "rotation_lambda_role_arn" {
  description = "ARN of the rotation Lambda IAM role"
  value       = var.enable_rotation_lambda ? aws_iam_role.rotation_lambda[0].arn : null
}