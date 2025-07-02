# Unit tests for monitoring module

run "monitoring_kubernetes" {
  command = plan

  module {
    source = "./modules/providers/kubernetes/monitoring"
  }

  variables {
    name        = "test-monitoring"
    environment = "test"
    config = {
      enable_prometheus   = true
      enable_grafana      = true
      enable_alertmanager = true
      storage_size        = "10Gi"
      retention_days      = 7
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = kubernetes_namespace.monitoring.metadata[0].name == "monitoring"
    error_message = "Monitoring namespace should be named 'monitoring'"
  }

  assert {
    condition     = length(helm_release.prometheus) == 1
    error_message = "Prometheus should be installed when enabled"
  }
}

run "monitoring_platform_interface" {
  command = plan

  module {
    source = "./modules/platform/monitoring"
  }

  variables {
    name        = "test-platform-monitoring"
    environment = "test"
    config = {
      enable_prometheus   = true
      enable_grafana      = true
      enable_alertmanager = true
      storage_size        = "10Gi"
      retention_days      = 7
    }
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = module.kubernetes_monitoring != null
    error_message = "Platform interface should delegate to Kubernetes implementation"
  }
}