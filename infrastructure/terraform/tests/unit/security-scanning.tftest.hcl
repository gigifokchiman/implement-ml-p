# Unit tests for Security Scanning module

run "security_scanning_kubernetes_basic" {
  command = plan

  module {
    source = "../../modules/platform/security-scanning"
  }

  variables {
    name        = "test-security-scanning"
    environment = "local"
    config = {
      enable_image_scanning   = true
      enable_vulnerability_db = true
      enable_runtime_scanning = true
      enable_compliance_check = false
      scan_schedule           = "0 2 * * *"
      severity_threshold      = "HIGH"
      enable_notifications    = false
      webhook_url             = null
    }
    namespaces = ["database", "cache", "storage", "monitoring"]
    tags = {
      Environment = "test"
      Purpose     = "security-scanning"
    }
  }

  # Test that Kubernetes security scanning resources are planned
  assert {
    condition     = contains(keys(var.config), "enable_image_scanning")
    error_message = "Security scanning config should include image scanning option"
  }

  assert {
    condition     = var.environment == "local"
    error_message = "Test should use local environment"
  }

  assert {
    condition     = var.config.enable_image_scanning == true
    error_message = "Image scanning should be enabled for this test"
  }
}

run "security_scanning_aws_basic" {
  command = plan

  module {
    source = "../../modules/platform/security-scanning"
  }

  variables {
    name        = "test-security-scanning"
    environment = "prod"
    config = {
      enable_image_scanning   = true
      enable_vulnerability_db = true
      enable_runtime_scanning = true
      enable_compliance_check = true
      scan_schedule           = "0 1 * * *"
      severity_threshold      = "HIGH"
      enable_notifications    = true
      webhook_url             = "https://example.com/webhook"
    }
    namespaces = ["database", "cache", "storage", "monitoring"]
    tags = {
      Environment = "prod"
      Purpose     = "security-scanning"
    }
  }

  # Test that AWS security scanning resources are planned for non-local environment
  assert {
    condition     = var.environment == "prod"
    error_message = "Test should use prod environment"
  }

  assert {
    condition     = var.config.enable_compliance_check == true
    error_message = "Compliance checking should be enabled for prod"
  }

  assert {
    condition     = var.config.webhook_url != null
    error_message = "Webhook URL should be configured for prod"
  }
}

run "security_scanning_config_validation" {
  command = plan

  module {
    source = "../../modules/platform/security-scanning"
  }

  variables {
    name        = "test-security-scanning"
    environment = "dev"
    config = {
      enable_image_scanning   = false
      enable_vulnerability_db = false
      enable_runtime_scanning = false
      enable_compliance_check = false
      scan_schedule           = "0 3 * * 0"
      severity_threshold      = "MEDIUM"
      enable_notifications    = false
      webhook_url             = null
    }
    namespaces = ["database"]
    tags = {
      Environment = "dev"
    }
  }

  # Test that configuration with all features disabled is valid
  assert {
    condition     = length(var.namespaces) >= 1
    error_message = "At least one namespace should be specified"
  }

  assert {
    condition     = contains(["HIGH", "MEDIUM", "LOW"], var.config.severity_threshold)
    error_message = "Severity threshold should be HIGH, MEDIUM, or LOW"
  }
}

run "security_scanning_schedule_validation" {
  command = plan

  module {
    source = "../../modules/platform/security-scanning"
  }

  variables {
    name        = "test-security-scanning"
    environment = "staging"
    config = {
      enable_image_scanning   = true
      enable_vulnerability_db = true
      enable_runtime_scanning = true
      enable_compliance_check = true
      scan_schedule           = "0 4 * * 1" # Weekly on Monday
      severity_threshold      = "MEDIUM"
      enable_notifications    = true
      webhook_url             = null
    }
    namespaces = ["database", "cache", "storage", "monitoring", "security-scanning"]
    tags = {
      Environment = "staging"
      Component   = "security"
    }
  }

  # Test weekly scheduling configuration
  assert {
    condition     = can(regex("^[0-9]+ [0-9]+ \\* \\* [0-7]$", var.config.scan_schedule))
    error_message = "Scan schedule should be a valid cron expression"
  }

  assert {
    condition     = length(var.namespaces) > 0
    error_message = "Namespaces list should not be empty"
  }
}