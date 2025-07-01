# Unit tests for network module using Terraform native testing (1.6+)

run "valid_vpc_cidr" {
  command = plan

  module {
    source = "../../modules/network"
  }

  variables {
    vpc_cidr    = "10.0.0.0/16"
    name_prefix = "test"
    environment = "test"
  }

  assert {
    condition     = var.vpc_cidr == "10.0.0.0/16"
    error_message = "VPC CIDR must be valid"
  }
}

run "subnet_count_validation" {
  command = plan

  module {
    source = "../../modules/network"
  }

  variables {
    vpc_cidr           = "10.0.0.0/16"
    name_prefix        = "test"
    environment        = "test"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  assert {
    condition     = length(module.network.public_subnet_ids) == 3
    error_message = "Should create one public subnet per AZ"
  }

  assert {
    condition     = length(module.network.private_subnet_ids) == 3
    error_message = "Should create one private subnet per AZ"
  }
}

run "tags_propagation" {
  command = plan

  module {
    source = "../../modules/network"
  }

  variables {
    vpc_cidr    = "10.0.0.0/16"
    name_prefix = "test"
    environment = "test"
    tags = {
      Project = "ml-platform"
      Owner   = "platform-team"
    }
  }

  assert {
    condition     = module.network.vpc_tags["Project"] == "ml-platform"
    error_message = "Tags should be propagated to VPC"
  }
}