output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM role ARN"
  value       = var.environment != "local" ? aws_iam_role.cluster_autoscaler_role[0].arn : ""
}

output "ml_workloads_node_group_arn" {
  description = "ML workloads node group ARN"
  value       = var.environment != "local" ? aws_eks_node_group.ml_workloads[0].arn : ""
}

output "general_node_group_arn" {
  description = "General workloads node group ARN"
  value       = var.environment != "local" ? aws_eks_node_group.general[0].arn : ""
}