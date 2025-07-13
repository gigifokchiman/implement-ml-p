# Platform Cluster Outputs

output "cluster_info" {
  description = "Unified cluster information"
  value       = local.cluster_info
  sensitive   = true
}

output "cluster_name" {
  description = "Cluster name"
  value       = local.cluster_info.name
}

output "cluster_endpoint" {
  description = "Cluster endpoint"
  value       = local.cluster_info.endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = local.cluster_info.version
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = local.cluster_info.ca_certificate
  sensitive   = true
}

output "provider_type" {
  description = "Cluster provider type (aws or kind)"
  value       = local.cluster_info.provider_type
}

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = local.cluster_info.kubeconfig
  sensitive   = true
}

# AWS-specific outputs (null for Kind)
output "vpc_id" {
  description = "VPC ID (AWS only)"
  value       = local.cluster_info.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs (AWS only)"
  value       = local.cluster_info.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs (AWS only)"
  value       = local.cluster_info.public_subnets
}

output "ecr_repository_url" {
  description = "ECR repository URL (AWS only)"
  value       = local.cluster_info.ecr_repository_url
}

# Pass-through AWS-specific outputs when available
output "aws_cluster_outputs" {
  description = "AWS-specific cluster outputs"
  value = var.use_aws ? {
    cluster_oidc_issuer_url   = module.aws_cluster[0].cluster_oidc_issuer_url
    cluster_oidc_provider_arn = module.aws_cluster[0].cluster_oidc_provider_arn
    irsa_role_arns            = module.aws_cluster[0].irsa_iam_role_arns
    efs_file_system_id        = module.aws_cluster[0].efs_file_system_id
    kms_key_id                = module.aws_cluster[0].kms_key_id
    kms_key_arn               = module.aws_cluster[0].kms_key_arn
    useful_commands           = module.aws_cluster[0].useful_commands
  } : null
  sensitive = true
}

# Pass-through Kind-specific outputs when available
output "kind_cluster_outputs" {
  description = "Kind-specific cluster outputs"
  value = var.use_aws ? null : {
    local_registry_url = try(module.kind_cluster[0].local_registry_url, null)
    kubeconfig_path    = try(module.kind_cluster[0].kubeconfig_path, null)
    port_mappings      = try(module.kind_cluster[0].port_mappings, null)
  }
  sensitive = true
}
