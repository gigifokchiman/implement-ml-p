# Service Registry Outputs

output "service_registry" {
  description = "Complete service registry"
  value       = local.service_registry
}

output "service_endpoints" {
  description = "Service discovery endpoints"
  value       = local.service_registry.endpoints
}

output "service_dependencies" {
  description = "Service dependency mapping"
  value       = local.service_registry.dependencies
}

output "registry_configmap" {
  description = "Registry ConfigMap reference"
  value = var.enable_service_registry ? {
    name      = kubernetes_config_map.service_registry[0].metadata[0].name
    namespace = kubernetes_config_map.service_registry[0].metadata[0].namespace
  } : {
    name      = "service-registry-disabled"
    namespace = "platform-system"
  }
}

# Helper functions for service discovery
output "service_discovery_functions" {
  description = "Helper functions for service discovery"
  value = {
    # Check if service is ready
    is_service_ready = {
      for name, service in local.service_registry.services :
      name => service.status == "ready"
    }
    
    # Get service endpoint
    get_service_endpoint = {
      for name, service in local.service_registry.services :
      name => try(service.endpoint, null)
    }
    
    # Check service dependencies
    get_service_dependencies = local.service_registry.dependencies
  }
}