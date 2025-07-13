# AWS EKS Cluster Provider Outputs

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "node_groups" {
  description = "EKS node groups information"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.main.name
}

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = var.enable_efs ? aws_efs_file_system.eks_storage[0].id : null
}

output "efs_file_system_dns_name" {
  description = "EFS file system DNS name"
  value       = var.enable_efs ? aws_efs_file_system.eks_storage[0].dns_name : null
}

# Connection Information
output "kubectl_config_command" {
  description = "kubectl config command"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
}

output "kubeconfig" {
  description = "Kubeconfig for connecting to the cluster"
  value = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = null # Will be provided by aws-iam-authenticator
  }
  sensitive = true
}

# IAM Information
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = try(module.eks_iam.node_group_role_arn, null)
}

output "irsa_iam_role_arns" {
  description = "IAM role ARNs for IRSA"
  value       = try(module.eks_iam.irsa_role_arns, {})
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.kms.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.kms.key_arn
}

# Useful Commands
output "useful_commands" {
  description = "Useful commands for this cluster"
  value = {
    kubectl_config  = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
    get_nodes       = "kubectl get nodes -o wide"
    get_node_groups = "kubectl get nodes --show-labels"
    ecr_login       = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.main.repository_url}"
  }
}
