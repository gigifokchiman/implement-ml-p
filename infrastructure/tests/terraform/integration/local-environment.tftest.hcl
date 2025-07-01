# Integration tests for local environment
# These tests actually deploy infrastructure to validate end-to-end functionality

run "deploy_local_environment" {
  command = apply

  variables {
    project_name = "ml-platform-test"
    environment  = "test"
    region       = "us-east-1"
    
    common_tags = {
      Environment = "test"
      Project     = "ml-platform-test"
      ManagedBy   = "terraform"
      TestRun     = "true"
    }
    
    enable_monitoring = true
    enable_backup     = false
    development_mode  = true
    
    # Resource quotas for testing
    resource_quotas = {
      enabled = true
      compute = {
        requests_cpu    = "2"
        requests_memory = "4Gi"
        limits_cpu      = "4"
        limits_memory   = "8Gi"
      }
      storage = {
        requests_storage = "10Gi"
      }
    }
  }

  assert {
    condition     = kind_cluster.default.endpoint != ""
    error_message = "Kind cluster should be created with valid endpoint"
  }

  assert {
    condition     = can(regex("^kind-", kind_cluster.default.name))
    error_message = "Cluster name should start with 'kind-'"
  }

  assert {
    condition     = kind_cluster.default.kubeconfig_path != ""
    error_message = "Kubeconfig path should be available"
  }
}

run "verify_vpc_simulation" {
  command = apply

  variables {
    project_name = "ml-platform-test"
    environment  = "test"
    region       = "us-east-1"
    common_tags = {
      Environment = "test"
      Project     = "ml-platform-test"
    }
    development_mode = true
  }

  assert {
    condition     = length(module.local_network.subnet_namespaces) >= 5
    error_message = "Should create all required VPC simulation namespaces"
  }

  assert {
    condition     = module.local_network.vpc_simulation.enabled == true
    error_message = "VPC simulation should be enabled"
  }

  assert {
    condition     = length(module.local_network.network_policies) > 0
    error_message = "Network policies should be created"
  }
}

run "verify_monitoring_stack" {
  command = apply

  variables {
    project_name = "ml-platform-test"
    environment  = "test"
    region       = "us-east-1"
    common_tags = {
      Environment = "test"
      Project     = "ml-platform-test"
    }
    enable_monitoring = true
    development_mode  = true
  }

  assert {
    condition     = module.monitoring.prometheus_enabled == true
    error_message = "Prometheus should be enabled"
  }

  assert {
    condition     = module.monitoring.grafana_enabled == true
    error_message = "Grafana should be enabled"
  }

  assert {
    condition     = module.monitoring.grafana_external_url != ""
    error_message = "Grafana should have external URL configured"
  }
}

run "verify_database_deployment" {
  command = apply

  variables {
    project_name = "ml-platform-test"
    environment  = "test"
    region       = "us-east-1"
    common_tags = {
      Environment = "test"
      Project     = "ml-platform-test"
    }
    development_mode = true
    
    database_config = {
      storage_size = 20
      backup_retention_days = 1
      instance_class = "small"
    }
  }

  assert {
    condition     = module.database.connection.url != ""
    error_message = "Database should have connection URL"
  }

  assert {
    condition     = module.database.connection.port > 0
    error_message = "Database should have valid port"
  }
}

run "verify_storage_deployment" {
  command = apply

  variables {
    project_name = "ml-platform-test"
    environment  = "test"
    region       = "us-east-1"
    common_tags = {
      Environment = "test"
      Project     = "ml-platform-test"
    }
    development_mode = true
    
    storage_config = {
      minio_storage_size = "10Gi"
      backup_enabled = false
    }
  }

  assert {
    condition     = module.storage.connection.endpoint != ""
    error_message = "Storage should have endpoint"
  }

  assert {
    condition     = module.storage.credentials.access_key != ""
    error_message = "Storage should have access credentials"
  }

  assert {
    condition     = length(module.storage.connection.buckets) > 0
    error_message = "Storage should create default buckets"
  }
}

run "verify_cross_subnet_secrets" {
  command = apply

  variables {
    project_name = "ml-platform-test"
    environment  = "test"
    region       = "us-east-1"
    common_tags = {
      Environment = "test"
      Project     = "ml-platform-test"
    }
    development_mode = true
  }

  assert {
    condition     = kubernetes_secret.database_connection.metadata[0].name == "database-connection"
    error_message = "Database connection secret should be created"
  }

  assert {
    condition     = kubernetes_secret.redis_connection.metadata[0].name == "redis-connection"
    error_message = "Redis connection secret should be created"
  }

  assert {
    condition     = kubernetes_secret.s3_connection.metadata[0].name == "s3-connection"
    error_message = "S3 connection secret should be created"
  }
}