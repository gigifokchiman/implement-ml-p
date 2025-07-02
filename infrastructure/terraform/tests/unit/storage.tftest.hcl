# Unit tests for storage module

run "storage_kubernetes_local" {
  command = plan

  module {
    source = "./modules/providers/kubernetes/storage"
  }

  variables {
    name        = "test-storage"
    environment = "test"
    config = {
      versioning_enabled = false
      encryption_enabled = false
      lifecycle_enabled  = false
      buckets = [
        {
          name   = "test-bucket"
          public = false
        }
      ]
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = kubernetes_namespace.storage.metadata[0].name == "storage"
    error_message = "Storage namespace should be named 'storage'"
  }

  assert {
    condition     = kubernetes_deployment.minio.spec[0].replicas == 1
    error_message = "MinIO should have 1 replica in local mode"
  }

  assert {
    condition     = kubernetes_service.minio.spec[0].port[0].port == 9000
    error_message = "MinIO service should expose port 9000"
  }

  assert {
    condition     = length(kubernetes_job.create_buckets) == 1
    error_message = "Should create one job per bucket"
  }
}

run "storage_platform_interface" {
  command = plan

  module {
    source = "./modules/platform/storage"
  }

  variables {
    name        = "test-platform-storage"
    environment = "local"
    config = {
      versioning_enabled = false
      encryption_enabled = false
      lifecycle_enabled  = false
      buckets = [
        {
          name   = "test-bucket"
          public = false
        }
      ]
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = length(module.kubernetes_storage) == 1
    error_message = "Platform interface should delegate to Kubernetes implementation for local"
  }

  assert {
    condition     = length(module.aws_storage) == 0
    error_message = "AWS implementation should not be used for local environment"
  }
}