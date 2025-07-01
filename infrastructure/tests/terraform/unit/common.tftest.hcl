# Unit tests for common module

run "validate_name_prefix" {
  command = plan
  
  module {
    source = "../../../terraform/modules/common"
  }

  variables {
    project_name = "ml-platform"
    environment  = "test"
    region       = "us-east-1"
    common_tags = {
      Environment = "test"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = length(output.name_prefix) > 0
    error_message = "Name prefix should not be empty"
  }

  assert {
    condition     = output.environment == "test"
    error_message = "Environment should match input"
  }
}

run "validate_local_environment_detection" {
  command = plan
  
  module {
    source = "../../../terraform/modules/common"
  }

  variables {
    project_name = "ml-platform"
    environment  = "local"
    region       = "us-east-1"
    common_tags = {
      Environment = "local"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = output.is_local == true
    error_message = "Should detect local environment"
  }

  assert {
    condition     = output.is_development == true
    error_message = "Local should be considered development"
  }
}

run "validate_production_environment" {
  command = plan
  
  module {
    source = "../../../terraform/modules/common"
  }

  variables {
    project_name = "ml-platform"
    environment  = "prod"
    region       = "us-east-1"
    common_tags = {
      Environment = "prod"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = output.is_local == false
    error_message = "Production should not be local"
  }

  assert {
    condition     = output.is_development == false
    error_message = "Production should not be development"
  }
}

run "validate_node_groups_configuration" {
  command = plan
  
  module {
    source = "../../../terraform/modules/common"
  }

  variables {
    project_name = "ml-platform"
    environment  = "prod"
    region       = "us-east-1"
    common_tags = {
      Environment = "prod"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = length(output.default_node_groups) > 0
    error_message = "Should have default node groups defined"
  }

  # Validate all node groups have required attributes
  assert {
    condition = alltrue([
      for ng in output.default_node_groups : 
      ng.disk_size != null && ng.disk_size > 0
    ])
    error_message = "All node groups should have valid disk_size"
  }

  assert {
    condition = alltrue([
      for ng in output.default_node_groups : 
      length(ng.instance_types) > 0
    ])
    error_message = "All node groups should have instance types"
  }
}