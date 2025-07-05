# IAM module outputs

output "node_group_role_arn" {
  description = "IAM role ARN for EKS node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_group_role_name" {
  description = "IAM role name for EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "irsa_role_arns" {
  description = "IAM role ARNs for IRSA"
  value = {
    aws_load_balancer_controller = aws_iam_role.irsa_aws_load_balancer_controller.arn
    ebs_csi_driver              = aws_iam_role.irsa_ebs_csi_driver.arn
    efs_csi_driver              = aws_iam_role.irsa_efs_csi_driver.arn
    external_dns                = aws_iam_role.irsa_external_dns.arn
    cluster_autoscaler          = aws_iam_role.irsa_cluster_autoscaler.arn
  }
}

output "irsa_role_names" {
  description = "IAM role names for IRSA"
  value = {
    aws_load_balancer_controller = aws_iam_role.irsa_aws_load_balancer_controller.name
    ebs_csi_driver              = aws_iam_role.irsa_ebs_csi_driver.name
    efs_csi_driver              = aws_iam_role.irsa_efs_csi_driver.name
    external_dns                = aws_iam_role.irsa_external_dns.name
    cluster_autoscaler          = aws_iam_role.irsa_cluster_autoscaler.name
  }
}