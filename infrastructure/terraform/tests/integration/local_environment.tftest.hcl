# Integration tests for local environment

run "local_environment_complete" {
  command = plan

  module {
    source = "./environments/local"
  }

  variables {
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
  }

  assert {
    condition     = kind_cluster.default.name == "ml-platform-local"
    error_message = "Kind cluster should be named 'ml-platform-local'"
  }

  assert {
    condition     = module.ml_platform != null
    error_message = "ML platform composition should be instantiated"
  }

  assert {
    condition     = length(kind_cluster.default.kind_config[0].nodes) == 2
    error_message = "Kind cluster should have 2 nodes (1 control-plane, 1 worker)"
  }
}

run "local_environment_outputs" {
  command = plan

  module {
    source = "./environments/local"
  }

  variables {
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
  }

  assert {
    condition     = output.cluster_info != null
    error_message = "Cluster info output should be provided"
  }

  assert {
    condition     = output.database_connection != null
    error_message = "Database connection output should be provided"
  }

  assert {
    condition     = output.useful_commands != null
    error_message = "Useful commands output should be provided"
  }
}