# Unit tests for database module

run "database_kubernetes_local" {
  command = plan

  module {
    source = "./modules/providers/kubernetes/database"
  }

  variables {
    name        = "test-db"
    environment = "test"
    config = {
      engine         = "postgres"
      version        = "16"
      instance_class = "local"
      storage_size   = 10
      multi_az       = false
      encrypted      = false
      username       = "testuser"
      database_name  = "testdb"
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = kubernetes_namespace.database.metadata[0].name == "database"
    error_message = "Database namespace should be named 'database'"
  }

  assert {
    condition     = kubernetes_deployment.postgres.spec[0].replicas == 1
    error_message = "PostgreSQL should have 1 replica in local mode"
  }

  assert {
    condition     = kubernetes_service.postgres.spec[0].port[0].port == 5432
    error_message = "PostgreSQL service should expose port 5432"
  }
}

run "database_platform_interface" {
  command = plan

  module {
    source = "./modules/platform/database"
  }

  variables {
    name        = "test-platform-db"
    environment = "test"
    config = {
      engine         = "postgres"
      version        = "16"
      instance_class = "local"
      storage_size   = 10
      multi_az       = false
      encrypted      = false
      username       = "testuser"
      database_name  = "testdb"
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = module.database_impl != null
    error_message = "Platform interface should delegate to implementation module"
  }
}