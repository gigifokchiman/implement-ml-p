# Unit tests for cache module

run "cache_kubernetes_local" {
  command = plan

  module {
    source = "./modules/providers/kubernetes/cache"
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
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = kubernetes_namespace.cache.metadata[0].name == "cache"
    error_message = "Cache namespace should be named 'cache'"
  }

  assert {
    condition     = kubernetes_deployment.redis.spec[0].replicas == 1
    error_message = "Redis should have 1 replica in local mode"
  }

  assert {
    condition     = kubernetes_service.redis.spec[0].port[0].port == 6379
    error_message = "Redis service should expose port 6379"
  }
}

run "cache_platform_interface" {
  command = plan

  module {
    source = "./modules/platform/cache"
  }

  variables {
    name        = "test-platform-cache"
    environment = "test"
    config = {
      engine    = "redis"
      version   = "7.0"
      node_type = "local"
      num_nodes = 1
      encrypted = false
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = length(module.kubernetes_cache) == 1
    error_message = "Platform interface should delegate to Kubernetes implementation for local"
  }

  assert {
    condition     = length(module.aws_cache) == 0
    error_message = "AWS implementation should not be used for local environment"
  }
}