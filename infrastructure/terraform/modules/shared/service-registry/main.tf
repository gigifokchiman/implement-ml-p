# Service Discovery and Registry Module
# Provides service discovery capabilities for loosely coupled modules

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Service Registry ConfigMap (namespace managed by ArgoCD)
resource "kubernetes_config_map" "service_registry" {
  count = var.enable_service_registry ? 1 : 0
  
  metadata {
    name      = "platform-service-registry"
    namespace = var.registry_namespace
    labels = {
      "app.kubernetes.io/name"       = "service-registry"
      "app.kubernetes.io/component"  = "platform"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "services.json" = jsonencode(local.service_registry)
  }
  
  lifecycle {
    ignore_changes = [metadata[0].namespace]
  }
}

# Service registration logic
locals {
  # Registered services
  registered_services = merge(
    # Core platform services
    var.cluster_service != null ? {
      cluster = {
        name      = var.cluster_service.name
        type      = "cluster"
        status    = var.cluster_service.is_ready ? "ready" : "pending"
        endpoint  = var.cluster_service.endpoint
        version   = var.cluster_service.version
        provider  = var.cluster_service.is_aws ? "aws" : "local"
        metadata = {
          vpc_id = try(var.cluster_service.vpc_id, null)
          region = try(var.cluster_service.region, null)
        }
      }
    } : {},
    
    # Security services
    var.security_service != null ? {
      security = {
        name     = "security-bootstrap"
        type     = "security"
        status   = var.security_service.is_ready ? "ready" : "pending"
        services = {
          cert_manager = {
            enabled   = var.security_service.certificates.enabled
            namespace = var.security_service.certificates.namespace
            issuer    = var.security_service.certificates.issuer
          }
          ingress = {
            class     = var.security_service.ingress.class
            namespace = var.security_service.ingress.namespace
          }
          gitops = {
            enabled   = var.security_service.gitops.enabled
            namespace = var.security_service.gitops.namespace
          }
        }
      }
    } : {},
    
    # Additional registered services
    var.additional_services
  )

  # Service dependencies mapping
  service_dependencies = {
    security = var.cluster_service != null ? ["cluster"] : []
    monitoring = var.security_service != null ? ["cluster", "security"] : ["cluster"]
    storage = ["cluster"]
    database = ["cluster"]
    cache = ["cluster"]
  }

  # Service discovery endpoints
  service_endpoints = {
    for service_name, service in local.registered_services : 
    service_name => {
      internal = try(service.endpoint, null)
      external = try(service.external_endpoint, null)
      health   = "${service_name}/health"
      metrics  = "${service_name}/metrics"
    }
  }

  # Complete service registry
  service_registry = {
    version = "1.0"
    platform = var.platform_name
    environment = var.environment
    services = local.registered_services
    dependencies = local.service_dependencies
    endpoints = local.service_endpoints
  }
}

# Service health checks (disabled for now - managed by ArgoCD)
# resource "kubernetes_manifest" "service_health_check" {
#   for_each = var.enable_health_checks ? toset(keys(local.registered_services)) : toset([])
#   
#   manifest = {
#     apiVersion = "batch/v1"
#     kind       = "CronJob"
#     metadata = {
#       name      = "${each.key}-health-check"
#       namespace = var.registry_namespace
#       labels = {
#         "app.kubernetes.io/name"      = "health-check"
#         "app.kubernetes.io/component" = each.key
#         "platform.io/service"        = each.key
#       }
#     }
#     spec = {
#       schedule = "*/2 * * * *"  # Every 2 minutes
#       jobTemplate = {
#         spec = {
#           template = {
#             spec = {
#               restartPolicy = "OnFailure"
#               containers = [
#                 {
#                   name  = "health-check"
#                   image = "curlimages/curl:latest"
#                   command = [
#                     "sh", "-c",
#                     "curl -f ${local.service_endpoints[each.key].health} || exit 1"
#                   ]
#                 }
#               ]
#             }
#           }
#         }
#       }
#     }
#   }
# }