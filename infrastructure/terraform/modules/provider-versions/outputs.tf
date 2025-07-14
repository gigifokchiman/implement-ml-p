# Provider Version Management Module Outputs

# Core provider versions for current environment
output "provider_versions" {
  description = "Provider version constraints for the current environment"
  value = merge(
    {
      for provider, constraints in local.provider_constraints :
      provider => var.override_versions[provider] != null ? var.override_versions[provider] : constraints[var.environment]
    },
    var.enable_local_dev_providers ? {
      for provider, version in local.local_dev_versions :
      provider => "= ${version}"
    } : {}
  )
}

# Terraform version requirement
output "terraform_version" {
  description = "Required Terraform version"
  value       = var.terraform_version
}

# Required providers block for terraform configuration
output "required_providers" {
  description = "Complete required_providers block for terraform configuration"
  value = merge(
    {
      aws = {
        source  = "hashicorp/aws"
        version = local.provider_constraints.aws[var.environment]
      }
      kubernetes = {
        source  = "hashicorp/kubernetes"
        version = local.provider_constraints.kubernetes[var.environment]
      }
      helm = {
        source  = "hashicorp/helm"
        version = local.provider_constraints.helm[var.environment]
      }
      random = {
        source  = "hashicorp/random"
        version = local.provider_constraints.random[var.environment]
      }
      null = {
        source  = "hashicorp/null"
        version = local.provider_constraints.null[var.environment]
      }
      time = {
        source  = "hashicorp/time"
        version = local.provider_constraints.time[var.environment]
      }
      tls = {
        source  = "hashicorp/tls"
        version = local.provider_constraints.tls[var.environment]
      }
      local = {
        source  = "hashicorp/local"
        version = local.provider_constraints.local[var.environment]
      }
      external = {
        source  = "hashicorp/external"
        version = local.provider_constraints.external[var.environment]
      }
      archive = {
        source  = "hashicorp/archive"
        version = local.provider_constraints.archive[var.environment]
      }
      cloudinit = {
        source  = "hashicorp/cloudinit"
        version = local.provider_constraints.cloudinit[var.environment]
      }
    },
    var.enable_local_dev_providers ? {
      kind = {
        source  = "kind.local/gigifokchiman/kind"
        version = "= ${local.local_dev_versions.kind}"
      }
      docker = {
        source  = "kreuzwerker/docker"
        version = "= ${local.local_dev_versions.docker}"
      }
    } : {},
    var.custom_providers
  )
}

# AWS module versions
output "aws_module_versions" {
  description = "Approved AWS module versions"
  value       = local.aws_module_versions
}

# Environment strategy information
output "version_strategy" {
  description = "Version strategy for current environment"
  value       = local.version_strategies[var.environment]
}

# Security compliance status
output "security_compliance" {
  description = "Security compliance information"
  value = {
    environment         = var.environment
    security_policy     = var.security_policy
    critical_providers  = local.security_critical_providers
    exact_versions_only = var.environment == "prod" || var.environment == "staging"
  }
}

# Version matrix for all environments (for planning)
output "version_matrix" {
  description = "Complete version matrix across all environments"
  value = {
    for env in ["local", "dev", "staging", "prod"] : env => {
      for provider, constraints in local.provider_constraints :
      provider => constraints[env]
    }
  }
  sensitive = false
}
