# Enterprise Provider Version Management Module
# Based on Netflix/Airbnb patterns for centralized version control

required_version = ">= 1.6.0"

# Provider version matrix by environment and criticality
locals {
  # Base provider versions (approved by security team)
  base_versions = {
    aws        = "5.31.2"
    kubernetes = "2.24.0"
    helm       = "2.12.1"
    random     = "3.6.0"
    null       = "3.2.2"
    time       = "0.10.0"
    tls        = "4.0.5"
    local      = "2.4.1"
    external   = "2.3.2"
    archive    = "2.4.1"
    cloudinit  = "2.3.3"
  }

  # Local development specific providers
  local_dev_versions = {
    kind   = "0.1.4"
    docker = "3.0.2"
  }

  # AWS module versions (for consistency across environments)
  aws_module_versions = {
    eks             = "20.37.1"
    vpc             = "5.21.0"
    kms             = "3.1.1"
    secrets_manager = "1.3.1"
    iam             = "5.32.0"
    security_group  = "5.1.0"
  }

  # Environment-specific version strategies
  version_strategies = {
    local = {
      # More permissive for development speed
      strategy = "minor_updates"
      pattern  = "~>"
      suffix   = "" # Allow minor updates: ~> 5.31
    }
    dev = {
      # Conservative but allow patch updates for testing
      strategy = "patch_updates"
      pattern  = "~>"
      suffix   = ".0" # Pin to patch series: ~> 5.31.0
    }
    staging = {
      # Very conservative - only security patches
      strategy = "exact_version"
      pattern  = "="
      suffix   = "" # Exact version: = 5.31.2
    }
    prod = {
      # Exact versions only - maximum stability
      strategy = "exact_version"
      pattern  = "="
      suffix   = "" # Exact version: = 5.31.2
    }
  }

  # Security-critical providers that should always use exact versions
  security_critical_providers = [
    "aws",
    "kubernetes",
    "tls"
  ]

  # Generate version constraints based on environment and strategy
  provider_constraints = {
    for provider, version in local.base_versions : provider => {
      local   = local.version_strategies.local.strategy == "exact_version" || contains(local.security_critical_providers, provider) ? "= ${version}" : "${local.version_strategies.local.pattern} ${replace(version, "/\\.[0-9]+$/", local.version_strategies.local.suffix)}"
      dev     = local.version_strategies.dev.strategy == "exact_version" || contains(local.security_critical_providers, provider) ? "= ${version}" : "${local.version_strategies.dev.pattern} ${replace(version, "/\\.[0-9]+$/", local.version_strategies.dev.suffix)}"
      staging = "= ${version}" # Always exact for staging
      prod    = "= ${version}" # Always exact for production
    }
  }
}

# Validation checks (similar to Airbnb's approach)
# Validation checks (commented out for initial implementation)
# check "terraform_version" {
#   assert {
#     condition = can(regex("^1\\.[6-9]\\.|^1\\.[1-9][0-9]\\.", var.terraform_version))
#     error_message = "Terraform version must be 1.6.0 or higher for provider version management features."
#   }
# }

# check "environment_validation" {
#   assert {
#     condition = contains(["local", "dev", "staging", "prod"], var.environment)
#     error_message = "Environment must be one of: local, dev, staging, prod."
#   }
# }

# check "provider_security_compliance" {
#   assert {
#     condition = alltrue([
#       for provider in local.security_critical_providers :
#       can(regex("^= [0-9]+\\.[0-9]+\\.[0-9]+$", local.provider_constraints[provider][var.environment]))
#     ])
#     error_message = "Security-critical providers must use exact versions in all environments."
#   }
# }
