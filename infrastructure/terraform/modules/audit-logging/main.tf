# Audit Logging Module
# Creates audit policy ConfigMap for post-cluster configuration

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Create audit logging namespace
resource "kubernetes_namespace" "audit_logging" {
  metadata {
    name = "audit-logging"
    labels = merge(var.tags, {
      "team"                        = "platform-engineering"
      "cost-center"                 = "platform"
      "environment"                 = var.environment
      "workload-type"               = "security"
      "app.kubernetes.io/name"      = "audit-logging"
      "app.kubernetes.io/component" = "namespace"
    })
  }
}

# Audit policy ConfigMap (for reference and potential future use)
resource "kubernetes_config_map" "audit_policy" {
  metadata {
    name      = "audit-policy"
    namespace = kubernetes_namespace.audit_logging.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "audit-policy"
      "app.kubernetes.io/component" = "audit-logging"
    })
  }

  data = {
    "audit-policy.yaml" = file("${path.module}/audit-policy.yaml")
    "setup-instructions.md" = <<-EOF
      # Audit Logging Setup Instructions
      
      This ConfigMap contains the audit policy for Kubernetes audit logging.
      
      ## To enable audit logging on Kind cluster:
      
      1. Recreate cluster with audit configuration:
         ```bash
         make clean-tf-local
         make deploy-tf-local
         ```
      
      2. Verify audit logs:
         ```bash
         make audit-logs
         ```
      
      ## Audit Policy Features:
      - Logs security-relevant events (secrets, RBAC, certificates)
      - Monitors team namespace activities  
      - Tracks platform infrastructure changes
      - Configured audit log rotation (30 days, 3 backups, 100MB max)
      
      ## Viewing Logs:
      - Recent logs: `make audit-logs`
      - Real-time: `make audit-logs-follow`
    EOF
  }
}

# Create a DaemonSet to collect audit logs (optional)
resource "kubernetes_config_map" "audit_log_collector" {
  metadata {
    name      = "audit-log-collector-config"
    namespace = kubernetes_namespace.audit_logging.metadata[0].name
    labels = merge(var.tags, {
      "app.kubernetes.io/name"      = "audit-log-collector"
      "app.kubernetes.io/component" = "audit-logging"
    })
  }

  data = {
    "fluent-bit.conf" = <<-EOF
      [SERVICE]
          Flush         1
          Log_Level     info
          Daemon        off
          Parsers_File  parsers.conf

      [INPUT]
          Name              tail
          Path              /var/log/kubernetes/audit.log
          Parser            json
          Tag               kubernetes.audit
          Refresh_Interval  5
          Mem_Buf_Limit     5MB

      [OUTPUT]
          Name   stdout
          Match  kubernetes.audit
          Format json_lines
    EOF
    
    "parsers.conf" = <<-EOF
      [PARSER]
          Name        json
          Format      json
          Time_Key    timestamp
          Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    EOF
  }
}