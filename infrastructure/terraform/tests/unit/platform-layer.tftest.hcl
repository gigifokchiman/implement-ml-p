# Platform Layer Unit Tests
# Tests platform modules in isolation with mocked dependencies

run "test_database_platform_interface" {
  command = plan

  module {
    source = "../../modules/platform/database"
  }

  variables {
    name        = "test-database"
    environment = "test"
    config = {
      engine         = "postgres"
      version        = "16"
      instance_class = "local"
      storage_size   = 20
      multi_az       = false
      encrypted      = false
      username       = "admin"
      database_name  = "testdb"
    }
    provider_config = {
      vpc_id                = ""
      subnet_ids            = []
      allowed_cidr_blocks   = []
      backup_retention_days = 7
      deletion_protection   = false
      region                = ""
    }
    tags = {
      Environment = "test"
      Module      = "database"
    }
  }

  # Verify the module plans successfully
  assert {
    condition     = can(module.database)
    error_message = "Database platform module should plan successfully"
  }
}

run "test_cache_platform_interface" {
  command = plan

  module {
    source = "../../modules/platform/cache"
  }

  variables {
    name        = "test-cache"
    environment = "test"
    config = {
      engine    = "redis"
      version   = "7.0"
      node_type = "local"
      num_nodes = 1
      encrypted = false
    }
    provider_config = {
      vpc_id              = ""
      subnet_ids          = []
      allowed_cidr_blocks = []
      region              = ""
    }
    tags = {
      Environment = "test"
      Module      = "cache"
    }
  }

  assert {
    condition     = can(module.cache)
    error_message = "Cache platform module should plan successfully"
  }
}

run "test_storage_platform_interface" {
  command = plan

  module {
    source = "../../modules/platform/storage"
  }

  variables {
    name        = "test-storage"
    environment = "test"
    config = {
      versioning_enabled = true
      encryption_enabled = false
      lifecycle_enabled  = false
      buckets = [
        {
          name   = "test-bucket"
          public = false
        }
      ]
    }
    provider_config = {
      region = ""
    }
    tags = {
      Environment = "test"
      Module      = "storage"
    }
  }

  assert {
    condition     = can(module.storage)
    error_message = "Storage platform module should plan successfully"
  }
}

run "test_cluster_platform_interface" {
  command = plan

  module {
    source = "../../modules/platform/cluster"
  }

  variables {
    name               = "test-cluster"
    environment        = "test"
    use_aws            = false
    kubernetes_version = "1.28"
    vpc_cidr           = ""

    node_groups = {
      default = {
        instance_types = ["local"]
        capacity_type  = "ON_DEMAND"
        min_size       = 1
        max_size       = 3
        desired_size   = 1
        ami_type       = "local"
        disk_size      = 50
        labels = {
          node-role   = "default"
          environment = "test"
        }
        taints = {}
      }
    }

    access_entries      = {}
    enable_efs          = false
    enable_gpu_nodes    = false
    team_configurations = []
    port_mappings = [
      {
        container_port = 80
        host_port      = 8080
        protocol       = "TCP"
      }
    ]

    tags = {
      Environment = "test"
      Module      = "cluster"
    }
  }

  assert {
    condition     = can(module.cluster)
    error_message = "Cluster platform module should plan successfully"
  }
}