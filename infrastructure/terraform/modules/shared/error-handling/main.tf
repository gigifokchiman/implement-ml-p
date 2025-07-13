# Error Handling and Recovery Module
# Provides standardized error handling patterns across the platform


# Error Context ConfigMap
resource "kubernetes_config_map" "error_context" {
  metadata {
    name      = "${var.service_name}-error-context"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "error-handling"
      "app.kubernetes.io/component" = var.service_name
      "platform.io/error-boundary"  = "true"
    }
  }

  data = {
    "error-config.json" = jsonencode({
      service_name     = var.service_name
      environment      = var.environment
      retry_policy     = var.retry_policy
      circuit_breaker  = var.circuit_breaker_config
      fallback_mode    = var.fallback_config
      error_thresholds = var.error_thresholds
    })
  }
}

# Error handling logic
locals {
  # Determine if service is in error state
  service_healthy = var.health_checks.enabled ? (
    var.health_checks.last_check_status == "healthy" &&
    var.health_checks.error_rate < var.error_thresholds.max_error_rate
  ) : true

  # Circuit breaker state
  circuit_breaker_open = var.circuit_breaker_config.enabled ? (
    var.health_checks.consecutive_failures >= var.circuit_breaker_config.failure_threshold
  ) : false

  # Determine fallback strategy
  fallback_strategy = local.circuit_breaker_open ? (
    var.fallback_config.strategy
  ) : "normal"

  # Error recovery actions
  recovery_actions = {
    restart_required    = var.health_checks.consecutive_failures >= var.error_thresholds.restart_threshold
    scale_down_required = var.health_checks.error_rate > var.error_thresholds.scale_down_rate
    alert_required      = var.health_checks.error_rate > var.error_thresholds.alert_rate
  }
}

# Service health monitoring
resource "kubernetes_manifest" "health_monitor" {
  count = var.health_checks.enabled ? 1 : 0

  manifest = {
    apiVersion = "batch/v1"
    kind       = "CronJob"
    metadata = {
      name      = "${var.service_name}-health-monitor"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"      = "health-monitor"
        "app.kubernetes.io/component" = var.service_name
      }
    }
    spec = {
      schedule = var.health_checks.schedule
      jobTemplate = {
        spec = {
          template = {
            spec = {
              restartPolicy = "OnFailure"
              containers = [
                {
                  name  = "health-check"
                  image = "curlimages/curl:latest"
                  env = [
                    {
                      name  = "SERVICE_NAME"
                      value = var.service_name
                    },
                    {
                      name  = "HEALTH_ENDPOINT"
                      value = var.health_checks.endpoint
                    },
                    {
                      name  = "TIMEOUT"
                      value = tostring(var.health_checks.timeout_seconds)
                    }
                  ]
                  command = [
                    "/bin/sh", "-c",
                    <<-EOT
                    set -e
                    echo "Health check for $SERVICE_NAME starting..."
                    
                    # Perform health check with timeout
                    if timeout $TIMEOUT curl -f -s "$HEALTH_ENDPOINT" > /dev/null 2>&1; then
                      echo "Health check PASSED for $SERVICE_NAME"
                      kubectl patch configmap ${var.service_name}-health-status --patch '{"data":{"status":"healthy","last_check":"'$(date -Iseconds)'","consecutive_failures":"0"}}'
                    else
                      echo "Health check FAILED for $SERVICE_NAME"
                      CURRENT_FAILURES=$(kubectl get configmap ${var.service_name}-health-status -o jsonpath='{.data.consecutive_failures}' 2>/dev/null || echo "0")
                      NEW_FAILURES=$((CURRENT_FAILURES + 1))
                      kubectl patch configmap ${var.service_name}-health-status --patch '{"data":{"status":"unhealthy","last_check":"'$(date -Iseconds)'","consecutive_failures":"'$NEW_FAILURES'"}}'
                      exit 1
                    fi
                    EOT
                  ]
                }
              ]
              serviceAccountName = kubernetes_service_account.health_monitor[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

# Health status tracking
resource "kubernetes_config_map" "health_status" {
  count = var.health_checks.enabled ? 1 : 0

  metadata {
    name      = "${var.service_name}-health-status"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "health-status"
      "app.kubernetes.io/component" = var.service_name
    }
  }

  data = {
    status               = "unknown"
    last_check           = ""
    consecutive_failures = "0"
    error_rate           = "0.0"
  }
}

# Service account for health monitoring
resource "kubernetes_service_account" "health_monitor" {
  count = var.health_checks.enabled ? 1 : 0

  metadata {
    name      = "${var.service_name}-health-monitor"
    namespace = var.namespace
  }
}

# RBAC for health monitoring
resource "kubernetes_role" "health_monitor" {
  count = var.health_checks.enabled ? 1 : 0

  metadata {
    namespace = var.namespace
    name      = "${var.service_name}-health-monitor"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "patch", "update"]
  }
}

resource "kubernetes_role_binding" "health_monitor" {
  count = var.health_checks.enabled ? 1 : 0

  metadata {
    name      = "${var.service_name}-health-monitor"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.health_monitor[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.health_monitor[0].metadata[0].name
    namespace = var.namespace
  }
}

# Error recovery automation
resource "null_resource" "error_recovery" {
  count = var.auto_recovery.enabled ? 1 : 0

  triggers = {
    health_status   = var.health_checks.enabled ? "${var.service_name}-monitoring" : "disabled"
    recovery_config = jsonencode(var.auto_recovery)
  }

  provisioner "local-exec" {
    command = <<-EOT
    echo "Error recovery check for ${var.service_name}"
    
    # This would integrate with external monitoring/alerting systems
    # For now, we log the recovery configuration
    echo "Recovery strategy: ${var.auto_recovery.strategy}"
    echo "Max retries: ${var.auto_recovery.max_retries}"
    echo "Backoff strategy: ${var.auto_recovery.backoff_strategy}"
    EOT
  }
}
