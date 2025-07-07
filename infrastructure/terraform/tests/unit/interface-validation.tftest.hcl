# Interface Validation Unit Tests
# Tests interface contract validation logic

run "test_valid_cluster_interface" {
  command = plan

  module {
    source = "../../modules/shared/validation"
  }

  variables {
    cluster_interface = {
      name        = "test-cluster"
      endpoint    = "https://test-cluster.local"
      version     = "1.28"
      vpc_id      = null
      is_ready    = true
      is_aws      = false
      is_local    = true
    }
    security_interface = null
    provider_config = null
  }

  assert {
    condition = output.cluster_validation_passed == true
    error_message = "Valid cluster interface should pass validation"
  }
}

run "test_invalid_cluster_interface_missing_name" {
  command = plan
  expect_failures = [null_resource.validate_cluster_interface]

  module {
    source = "../../modules/shared/validation"
  }

  variables {
    cluster_interface = {
      name        = ""  # Invalid: empty name
      endpoint    = "https://test-cluster.local"
      version     = "1.28"
      vpc_id      = null
      is_ready    = true
      is_aws      = false
      is_local    = true
    }
    security_interface = null
    provider_config = null
  }
}

run "test_valid_security_interface" {
  command = plan

  module {
    source = "../../modules/shared/validation"
  }

  variables {
    cluster_interface = null
    security_interface = {
      certificates = {
        enabled   = true
        namespace = "cert-manager"
        issuer    = "letsencrypt"
      }
      ingress = {
        class     = "nginx"
        namespace = "ingress-nginx"
      }
      gitops = {
        enabled   = true
        namespace = "argocd"
      }
      is_ready = true
    }
    provider_config = null
  }

  assert {
    condition = output.security_validation_passed == true
    error_message = "Valid security interface should pass validation"
  }
}

run "test_valid_provider_config" {
  command = plan

  module {
    source = "../../modules/shared/validation"
  }

  variables {
    cluster_interface = null
    security_interface = null
    provider_config = {
      vpc_id                = "vpc-12345"
      subnet_ids            = ["subnet-1", "subnet-2"]
      allowed_cidr_blocks   = ["10.0.0.0/16", "172.16.0.0/12"]
      backup_retention_days = 30
      deletion_protection   = true
      region                = "us-west-2"
    }
  }

  assert {
    condition = output.provider_validation_passed == true
    error_message = "Valid provider config should pass validation"
  }
}

run "test_invalid_provider_config_inconsistent_vpc" {
  command = plan
  expect_failures = [null_resource.validate_provider_config]

  module {
    source = "../../modules/shared/validation"
  }

  variables {
    cluster_interface = null
    security_interface = null
    provider_config = {
      vpc_id                = "vpc-12345"  # VPC specified
      subnet_ids            = []           # But no subnets - inconsistent
      allowed_cidr_blocks   = ["10.0.0.0/16"]
      backup_retention_days = 30
      deletion_protection   = true
      region                = "us-west-2"
    }
  }
}

run "test_invalid_provider_config_bad_cidr" {
  command = plan
  expect_failures = [null_resource.validate_provider_config]

  module {
    source = "../../modules/shared/validation"
  }

  variables {
    cluster_interface = null
    security_interface = null
    provider_config = {
      vpc_id                = ""
      subnet_ids            = []
      allowed_cidr_blocks   = ["invalid-cidr", "10.0.0.0/16"]  # Invalid CIDR
      backup_retention_days = 30
      deletion_protection   = true
      region                = ""
    }
  }
}