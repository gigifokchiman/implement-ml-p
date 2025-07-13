# Interface Contract Validation Module
# Validates that interfaces conform to expected contracts


# Validate cluster interface contract
resource "null_resource" "validate_cluster_interface" {
  count = var.cluster_interface != null ? 1 : 0

  triggers = {
    validation = jsonencode({
      # Required fields validation
      name_present     = var.cluster_interface.name != null && var.cluster_interface.name != ""
      endpoint_present = var.cluster_interface.endpoint != null && var.cluster_interface.endpoint != ""
      version_present  = var.cluster_interface.version != null && var.cluster_interface.version != ""
      is_ready_present = var.cluster_interface.is_ready != null

      # Type validation
      name_type     = can(tostring(var.cluster_interface.name))
      endpoint_type = can(tostring(var.cluster_interface.endpoint))
      version_type  = can(tostring(var.cluster_interface.version))
      is_ready_type = can(tobool(var.cluster_interface.is_ready))

      # Logical validation
      ready_state = var.cluster_interface.is_ready == true ? (
        var.cluster_interface.name != "" && var.cluster_interface.endpoint != ""
      ) : true
    })
  }

  lifecycle {
    precondition {
      condition = var.cluster_interface == null || (
        var.cluster_interface.name != null &&
        var.cluster_interface.name != "" &&
        var.cluster_interface.endpoint != null &&
        var.cluster_interface.endpoint != "" &&
        var.cluster_interface.version != null &&
        var.cluster_interface.version != ""
      )
      error_message = "Cluster interface is missing required fields: name, endpoint, or version"
    }

    precondition {
      condition = var.cluster_interface == null || (
        var.cluster_interface.is_ready != true ||
        (var.cluster_interface.name != "" && var.cluster_interface.endpoint != "")
      )
      error_message = "Cluster interface marked as ready but missing name or endpoint"
    }
  }
}

# Validate security interface contract
resource "null_resource" "validate_security_interface" {
  count = var.security_interface != null ? 1 : 0

  triggers = {
    validation = jsonencode({
      # Required fields validation
      certificates_present = var.security_interface.certificates != null
      ingress_present      = var.security_interface.ingress != null
      gitops_present       = var.security_interface.gitops != null

      # Nested structure validation
      cert_enabled   = can(tobool(var.security_interface.certificates.enabled))
      cert_namespace = can(tostring(var.security_interface.certificates.namespace))
      ingress_class  = can(tostring(var.security_interface.ingress.class))
      gitops_enabled = can(tobool(var.security_interface.gitops.enabled))
    })
  }

  lifecycle {
    precondition {
      condition = var.security_interface == null || (
        var.security_interface.certificates != null &&
        var.security_interface.ingress != null &&
        var.security_interface.gitops != null
      )
      error_message = "Security interface is missing required nested objects: certificates, ingress, or gitops"
    }

    precondition {
      condition = var.security_interface == null || (
        can(tobool(var.security_interface.certificates.enabled)) &&
        can(tostring(var.security_interface.certificates.namespace)) &&
        can(tostring(var.security_interface.ingress.class)) &&
        can(tobool(var.security_interface.gitops.enabled))
      )
      error_message = "Security interface has invalid field types in nested objects"
    }
  }
}

# Validate provider configuration contract
resource "null_resource" "validate_provider_config" {
  count = var.provider_config != null ? 1 : 0

  triggers = {
    validation = jsonencode({
      # Network configuration validation (for AWS)
      vpc_subnets_consistent = (
        var.provider_config.vpc_id != "" && length(var.provider_config.subnet_ids) > 0
        ) || (
        var.provider_config.vpc_id == "" && length(var.provider_config.subnet_ids) == 0
      )

      # CIDR validation
      valid_cidrs = alltrue([
        for cidr in var.provider_config.allowed_cidr_blocks :
        can(cidrhost(cidr, 0))
      ])

      # Numeric constraints
      valid_retention = var.provider_config.backup_retention_days >= 1 && var.provider_config.backup_retention_days <= 365
    })
  }

  lifecycle {
    precondition {
      condition = var.provider_config == null || (
        (var.provider_config.vpc_id != "" && length(var.provider_config.subnet_ids) > 0) ||
        (var.provider_config.vpc_id == "" && length(var.provider_config.subnet_ids) == 0)
      )
      error_message = "Provider config: VPC ID and subnet IDs must be consistent (both empty or both populated)"
    }

    precondition {
      condition = var.provider_config == null || alltrue([
        for cidr in var.provider_config.allowed_cidr_blocks :
        can(cidrhost(cidr, 0))
      ])
      error_message = "Provider config: Invalid CIDR blocks in allowed_cidr_blocks"
    }

    precondition {
      condition = var.provider_config == null || (
        var.provider_config.backup_retention_days >= 1 && var.provider_config.backup_retention_days <= 365
      )
      error_message = "Provider config: backup_retention_days must be between 1 and 365"
    }
  }
}

# Output validation results
locals {
  validation_results = {
    cluster_valid  = var.cluster_interface != null ? true : null
    security_valid = var.security_interface != null ? true : null
    provider_valid = var.provider_config != null ? true : null

    validation_summary = {
      total_validations = (
        (var.cluster_interface != null ? 1 : 0) +
        (var.security_interface != null ? 1 : 0) +
        (var.provider_config != null ? 1 : 0)
      )
      passed_validations = (
        (var.cluster_interface != null ? 1 : 0) +
        (var.security_interface != null ? 1 : 0) +
        (var.provider_config != null ? 1 : 0)
      )
    }
  }
}
