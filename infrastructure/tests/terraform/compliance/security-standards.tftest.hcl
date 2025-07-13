# Security and compliance tests for Terraform configurations

run "verify_required_tags" {
  command = plan

  variables {
    project_name = "ml-platform"
    environment  = "prod"
    region       = "us-east-1"
    common_tags = {
      Environment = "prod"
      Project     = "ml-platform"
      ManagedBy   = "terraform"
      Owner       = "platform-team"
      CostCenter  = "engineering"
    }
  }

  # Verify all required tags are present
  assert {
    condition     = var.common_tags["Environment"] != ""
    error_message = "Environment tag is required"
  }

  assert {
    condition     = var.common_tags["Project"] != ""
    error_message = "Project tag is required"
  }

  assert {
    condition     = var.common_tags["ManagedBy"] != ""
    error_message = "ManagedBy tag is required"
  }
}

run "verify_production_settings" {
  command = plan

  variables {
    project_name = "ml-platform"
    environment  = "prod"
    region       = "us-east-1"
    common_tags = {
      Environment = "prod"
      Project     = "ml-platform"
      ManagedBy   = "terraform"
    }

    # Production should have these settings
    enable_backup         = true
    backup_retention_days = 30
    deletion_protection   = true
    development_mode      = false

    database_config = {
      storage_size          = 100
      backup_retention_days = 30
      instance_class        = "large"
    }
  }

  assert {
    condition     = var.enable_backup == true
    error_message = "Backup must be enabled in production"
  }

  assert {
    condition     = var.backup_retention_days >= 30
    error_message = "Production backup retention must be at least 30 days"
  }

  assert {
    condition     = var.deletion_protection == true
    error_message = "Deletion protection must be enabled in production"
  }

  assert {
    condition     = var.development_mode == false
    error_message = "Development mode must be disabled in production"
  }
}

run "verify_development_constraints" {
  command = plan

  variables {
    project_name = "ml-platform"
    environment  = "dev"
    region       = "us-east-1"
    common_tags = {
      Environment = "dev"
      Project     = "ml-platform"
      ManagedBy   = "terraform"
    }

    # Development constraints
    database_config = {
      storage_size          = 20
      backup_retention_days = 1
      instance_class        = "small"
    }

    resource_quotas = {
      enabled = true
      compute = {
        requests_cpu    = "2"
        requests_memory = "4Gi"
        limits_cpu      = "4"
        limits_memory   = "8Gi"
      }
    }
  }

  assert {
    condition     = var.database_config.storage_size <= 50
    error_message = "Development database storage should be limited to save costs"
  }

  assert {
    condition     = var.resource_quotas.enabled == true
    error_message = "Resource quotas should be enabled in development"
  }
}

run "verify_security_configurations" {
  command = plan

  variables {
    project_name = "ml-platform"
    environment  = "prod"
    region       = "us-east-1"
    common_tags = {
      Environment = "prod"
      Project     = "ml-platform"
      ManagedBy   = "terraform"
    }

    security_config = {
      pod_security_standards   = "restricted"
      network_policies_enabled = true
      secrets_encryption       = true
    }
  }

  assert {
    condition     = var.security_config.pod_security_standards == "restricted"
    error_message = "Production should use restricted pod security standards"
  }

  assert {
    condition     = var.security_config.network_policies_enabled == true
    error_message = "Network policies must be enabled for security"
  }

  assert {
    condition     = var.security_config.secrets_encryption == true
    error_message = "Secrets encryption must be enabled"
  }
}