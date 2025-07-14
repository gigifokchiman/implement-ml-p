# Centralized Provider Version Management
# This file defines all provider versions used across environments
# Update versions here and they will apply to all environments

locals {
  # Terraform version requirements
  terraform_version = ">= 1.6.0"

  # Core provider versions (used across all environments)
  provider_versions = {
    aws        = "~> 5.0"
    kubernetes = "~> 2.23"
    helm       = "~> 2.11"
    random     = "~> 3.5"
    null       = "~> 3.2"
    time       = "~> 0.9"
    tls        = "~> 4.0"
    local      = "~> 2.4"
    external   = "~> 2.3"
    archive    = "~> 2.4"
    cloudinit  = ">= 2.0.0"
  }

  # Environment-specific provider versions
  local_providers = {
    kind   = "0.1.4"
    docker = "~> 3.0"
  }

  # AWS module versions (for consistency)
  aws_module_versions = {
    eks             = "20.37.1"
    vpc             = "5.21.0"
    kms             = "3.1.1"
    secrets_manager = "1.3.1"
  }
}