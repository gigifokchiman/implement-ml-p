# Provider Version Management Module Variables

variable "environment" {
  description = "Target environment (local, dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: local, dev, staging, prod."
  }
}

variable "terraform_version" {
  description = "Required Terraform version"
  type        = string
  default     = ">= 1.6.0"
}

variable "enable_local_dev_providers" {
  description = "Enable local development providers (kind, docker)"
  type        = bool
  default     = false
}

variable "override_versions" {
  description = "Override specific provider versions (emergency use)"
  type        = map(string)
  default     = {}
  validation {
    condition = alltrue([
      for version in values(var.override_versions) :
      can(regex("^[~>=]?\\s*[0-9]+\\.[0-9]+\\.[0-9]+$", version))
    ])
    error_message = "Override versions must follow semantic versioning format."
  }
}

variable "custom_providers" {
  description = "Additional custom providers with versions"
  type = map(object({
    source  = string
    version = string
  }))
  default = {}
}

variable "security_policy" {
  description = "Security policy level (strict, balanced, permissive)"
  type        = string
  default     = "balanced"
  validation {
    condition     = contains(["strict", "balanced", "permissive"], var.security_policy)
    error_message = "Security policy must be one of: strict, balanced, permissive."
  }
}
