# Unit tests for ML platform composition

run "ml_platform_composition" {
  command = plan

  module {
    source = "./modules/compositions/ml-platform"
  }

  variables {
    name        = "test-ml-platform"
    environment = "local"
    database_config = {
      engine         = "postgres"
      version        = "16"
      instance_class = "local"
      storage_size   = 10
      multi_az       = false
      encrypted      = false
      username       = "admin"
      database_name  = "metadata"
    }
    cache_config = {
      engine    = "redis"
      version   = "7.0"
      node_type = "local"
      num_nodes = 1
      encrypted = false
    }
    storage_config = {
      versioning_enabled = false
      encryption_enabled = false
      lifecycle_enabled  = false
      buckets = [
        {
          name   = "ml-artifacts"
          public = false
        }
      ]
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = module.database != null
    error_message = "Database module should be instantiated"
  }

  assert {
    condition     = module.cache != null
    error_message = "Cache module should be instantiated"
  }

  assert {
    condition     = module.storage != null
    error_message = "Storage module should be instantiated"
  }

  assert {
    condition     = module.monitoring != null
    error_message = "Monitoring module should be instantiated"
  }
}