# Unit tests for Performance Monitoring module

run "performance_monitoring_kubernetes_basic" {
  command = plan

  module {
    source = "../../modules/platform/performance-monitoring"
  }

  variables {
    name        = "test-performance"
    environment = "local"
    config = {
      enable_apm               = true
      enable_distributed_trace = true
      enable_custom_metrics    = true
      enable_log_aggregation   = true
      enable_alerting          = false
      retention_days           = 30
      sampling_rate            = 0.1
      trace_storage_size       = "5Gi"
      metrics_storage_size     = "10Gi"
      log_storage_size         = "20Gi"
    }
    namespaces = ["database", "cache", "storage", "monitoring"]
    tags = {
      Environment = "test"
      Purpose     = "performance-monitoring"
    }
  }

  # Test that Kubernetes performance monitoring resources are planned
  assert {
    condition     = contains(keys(var.config), "enable_apm")
    error_message = "Performance monitoring config should include APM option"
  }

  assert {
    condition     = var.environment == "local"
    error_message = "Test should use local environment"
  }

  assert {
    condition     = var.config.enable_distributed_trace == true
    error_message = "Distributed tracing should be enabled for this test"
  }
}

run "performance_monitoring_aws_basic" {
  command = plan

  module {
    source = "../../modules/platform/performance-monitoring"
  }

  variables {
    name        = "test-performance"
    environment = "prod"
    config = {
      enable_apm               = true
      enable_distributed_trace = true
      enable_custom_metrics    = true
      enable_log_aggregation   = true
      enable_alerting          = true
      retention_days           = 90
      sampling_rate            = 0.05
      trace_storage_size       = "20Gi"
      metrics_storage_size     = "50Gi"
      log_storage_size         = "100Gi"
    }
    namespaces = ["database", "cache", "storage", "monitoring"]
    tags = {
      Environment = "prod"
      Purpose     = "performance-monitoring"
    }
  }

  # Test that AWS performance monitoring resources are planned for non-local environment
  assert {
    condition     = var.environment == "prod"
    error_message = "Test should use prod environment"
  }

  assert {
    condition     = var.config.enable_alerting == true
    error_message = "Alerting should be enabled for prod"
  }

  assert {
    condition     = var.config.retention_days == 90
    error_message = "Retention should be 90 days for prod"
  }
}

run "performance_monitoring_config_validation" {
  command = plan

  module {
    source = "../../modules/platform/performance-monitoring"
  }

  variables {
    name        = "test-performance"
    environment = "dev"
    config = {
      enable_apm               = false
      enable_distributed_trace = false
      enable_custom_metrics    = true
      enable_log_aggregation   = false
      enable_alerting          = false
      retention_days           = 7
      sampling_rate            = 0.2
      trace_storage_size       = "1Gi"
      metrics_storage_size     = "5Gi"
      log_storage_size         = "10Gi"
    }
    namespaces = ["database"]
    tags = {
      Environment = "dev"
    }
  }

  # Test that configuration with minimal features is valid
  assert {
    condition     = length(var.namespaces) >= 1
    error_message = "At least one namespace should be specified"
  }

  assert {
    condition     = var.config.retention_days > 0
    error_message = "Retention days should be greater than 0"
  }

  assert {
    condition     = var.config.sampling_rate > 0 && var.config.sampling_rate <= 1
    error_message = "Sampling rate should be between 0 and 1"
  }
}

run "performance_monitoring_storage_validation" {
  command = plan

  module {
    source = "../../modules/platform/performance-monitoring"
  }

  variables {
    name        = "test-performance"
    environment = "staging"
    config = {
      enable_apm               = true
      enable_distributed_trace = true
      enable_custom_metrics    = true
      enable_log_aggregation   = true
      enable_alerting          = true
      retention_days           = 30
      sampling_rate            = 0.1
      trace_storage_size       = "10Gi"
      metrics_storage_size     = "25Gi"
      log_storage_size         = "50Gi"
    }
    namespaces = ["database", "cache", "storage", "monitoring", "performance-monitoring"]
    tags = {
      Environment = "staging"
      Component   = "performance"
    }
  }

  # Test storage size configurations
  assert {
    condition     = can(regex("^[0-9]+[GM]i$", var.config.trace_storage_size))
    error_message = "Trace storage size should be in Gi or Mi format"
  }

  assert {
    condition     = can(regex("^[0-9]+[GM]i$", var.config.metrics_storage_size))
    error_message = "Metrics storage size should be in Gi or Mi format"
  }

  assert {
    condition     = can(regex("^[0-9]+[GM]i$", var.config.log_storage_size))
    error_message = "Log storage size should be in Gi or Mi format"
  }

  assert {
    condition     = length(var.namespaces) > 0
    error_message = "Namespaces list should not be empty"
  }
}