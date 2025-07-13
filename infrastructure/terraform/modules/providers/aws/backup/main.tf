# AWS Backup Module
# Creates AWS Backup resources for data protection

locals {
  common_tags = merge(var.tags, {
    Component = "backup"
    Provider  = "aws"
  })
}

# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.name}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = local.common_tags
}

# AWS Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.name}-backup-plan"

  rule {
    rule_name         = var.backup_rule_name
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_schedule

    lifecycle {
      cold_storage_after = var.cold_storage_after
      delete_after       = var.delete_after
    }

    recovery_point_tags = local.common_tags
  }

  tags = local.common_tags
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach AWS managed policy to backup role
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Backup selection for RDS databases
resource "aws_backup_selection" "rds" {
  count = var.backup_rds_enabled ? 1 : 0

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-rds-backup-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupEnabled"
    value = "true"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = var.environment
  }
}

# Backup selection for EBS volumes
resource "aws_backup_selection" "ebs" {
  count = var.backup_ebs_enabled ? 1 : 0

  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-ebs-backup-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupEnabled"
    value = "true"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "ResourceType"
    value = "EBS"
  }
}
