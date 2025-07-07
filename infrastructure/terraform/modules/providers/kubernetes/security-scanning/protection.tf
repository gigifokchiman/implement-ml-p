# Protection mechanisms for security scanning infrastructure

# Network policy - Allow security tools to scan all namespaces
resource "kubernetes_network_policy" "security_scanner_access" {
  metadata {
    name      = "security-scanner-access"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/part-of" = "security-scanning"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Allow all egress for scanning
    egress {
      to {
        namespace_selector {}
      }
      to {
        pod_selector {}
      }
    }

    # Allow ingress from monitoring and ArgoCD
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "name" = "monitoring"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "name" = "argocd"
          }
        }
      }
    }
  }
}

# ResourceQuota to ensure security tools have resources
resource "kubernetes_resource_quota" "security_scanning" {
  metadata {
    name      = "security-scanning-quota"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  spec {
    hard = {
      "requests.cpu"           = "4"
      "requests.memory"        = "8Gi"
      "limits.cpu"             = "8"
      "limits.memory"          = "16Gi"
      "persistentvolumeclaims" = "10"
    }
  }
}

# PriorityClass for security workloads
resource "kubernetes_priority_class" "security_critical" {
  metadata {
    name   = "security-critical"
    labels = local.security_labels
  }

  value       = 1000000000 # Highest priority
  description = "Critical security scanning workloads"

  global_default    = false
  preemption_policy = "PreemptLowerPriority"
}

# ConfigMap for security policies
resource "kubernetes_config_map" "security_policies" {
  metadata {
    name      = "security-policies"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  data = {
    "scan-policy.yaml" = yamlencode({
      scanPolicy = {
        namespaceSelector = {
          matchLabels = {} # Scan all namespaces
        }
        scanInterval      = "1h"
        severityThreshold = "MEDIUM"
        ignoreUnfixed     = false
      }
    })

    "compliance-policy.yaml" = yamlencode({
      compliancePolicy = {
        standards    = ["CIS", "PCI-DSS", "NIST"]
        scanSchedule = "0 */6 * * *" # Every 6 hours
      }
    })
  }
}

# Secret for external integrations (managed by Terraform)
resource "kubernetes_secret" "security_integrations" {
  metadata {
    name      = "security-integrations"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels

    annotations = {
      "security.platform/purpose" = "External security tool integrations"
    }
  }

  type = "Opaque"

  data = {
    # These would be populated from secure sources
    "webhook-url" = base64encode(var.security_webhook_url != "" ? var.security_webhook_url : "https://placeholder.webhook.url")
    "registry-config" = base64encode(jsonencode({
      registries = var.registry_configs
    }))
  }
}