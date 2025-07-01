# Integration tests for local environment

run "create_kind_cluster" {
  command = apply

  variables {
    environment  = "test"
    project_name = "ml-platform-test"
  }

  assert {
    condition     = kind_cluster.default.endpoint != ""
    error_message = "Kind cluster endpoint should be available"
  }

  assert {
    condition     = can(regex("^kind-", kind_cluster.default.name))
    error_message = "Cluster name should start with 'kind-'"
  }
}

run "verify_cluster_nodes" {
  command = apply

  variables {
    environment  = "test"
    project_name = "ml-platform-test"
  }

  assert {
    condition     = length(kind_cluster.default.nodes) >= 2
    error_message = "Cluster should have at least 2 nodes"
  }
}

run "verify_namespaces" {
  command = apply

  variables {
    environment  = "test"
    project_name = "ml-platform-test"
  }

  assert {
    condition     = kubernetes_namespace.ml_platform.metadata[0].name != ""
    error_message = "ML platform namespace should be created"
  }

  assert {
    condition     = module.local_network.subnet_namespaces["public"] != ""
    error_message = "Public subnet namespace should be created"
  }

  assert {
    condition     = module.local_network.subnet_namespaces["private"] != ""
    error_message = "Private subnet namespace should be created"
  }
}

run "verify_network_policies" {
  command = apply

  variables {
    environment  = "test"
    project_name = "ml-platform-test"
  }

  assert {
    condition     = length(module.local_network.network_policies) > 0
    error_message = "Network policies should be created for VPC simulation"
  }
}

run "verify_monitoring_stack" {
  command = apply

  variables {
    environment       = "test"
    project_name      = "ml-platform-test"
    enable_monitoring = true
  }

  assert {
    condition     = module.monitoring.prometheus_enabled
    error_message = "Prometheus should be enabled when monitoring is enabled"
  }

  assert {
    condition     = module.monitoring.grafana_enabled
    error_message = "Grafana should be enabled when monitoring is enabled"
  }
}