# Unit tests for local-network module

run "validate_vpc_simulation_namespaces" {
  command = plan

  module {
    source = "../../../terraform/modules/local-network"
  }

  variables {
    name_prefix  = "ml-platform-test"
    environment  = "test"
    cluster_name = "test-cluster"
    tags = {
      Environment = "test"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = length(keys(output.subnet_namespaces)) >= 5
    error_message = "Should create at least 5 VPC simulation namespaces"
  }

  assert {
    condition     = contains(keys(output.subnet_namespaces), "public")
    error_message = "Should include public subnet namespace"
  }

  assert {
    condition     = contains(keys(output.subnet_namespaces), "private")
    error_message = "Should include private subnet namespace"
  }

  assert {
    condition     = contains(keys(output.subnet_namespaces), "database")
    error_message = "Should include database subnet namespace"
  }

  assert {
    condition     = contains(keys(output.subnet_namespaces), "ml-workload")
    error_message = "Should include ml-workload subnet namespace"
  }

  assert {
    condition     = contains(keys(output.subnet_namespaces), "monitoring")
    error_message = "Should include monitoring subnet namespace"
  }
}

run "validate_network_policies_creation" {
  command = plan

  module {
    source = "../../../terraform/modules/local-network"
  }

  variables {
    name_prefix            = "ml-platform-test"
    environment            = "test"
    cluster_name           = "test-cluster"
    enable_strict_policies = true
    tags = {
      Environment = "test"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = length(output.network_policies) > 0
    error_message = "Should create network policies for VPC simulation"
  }
}

run "validate_cross_subnet_communication" {
  command = plan

  module {
    source = "../../../terraform/modules/local-network"
  }

  variables {
    name_prefix  = "ml-platform-test"
    environment  = "test"
    cluster_name = "test-cluster"
    allow_cross_subnet_communication = {
      public_to_private           = true
      private_to_database         = true
      ml_workload_to_database     = true
      data_processing_to_database = true
      monitoring_to_all           = true
    }
    tags = {
      Environment = "test"
      Project     = "ml-platform"
    }
  }

  assert {
    condition     = output.vpc_simulation.enabled == true
    error_message = "VPC simulation should be enabled"
  }
}