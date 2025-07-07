# Admission webhook to protect security resources

# Create a self-signed certificate for the webhook
resource "kubernetes_secret" "webhook_certs" {
  metadata {
    name      = "security-webhook-certs"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  type = "kubernetes.io/tls"

  data = {
    # In production, use cert-manager or proper PKI
    "tls.crt" = base64encode("placeholder-cert")
    "tls.key" = base64encode("placeholder-key")
  }
}

# ValidatingWebhookConfiguration to prevent deletion of security resources
resource "kubernetes_validating_webhook_configuration_v1" "protect_security" {
  metadata {
    name   = "protect-security-resources"
    labels = local.security_labels
  }

  webhook {
    name = "prevent-security-deletion.security.platform"
    
    admission_review_versions = ["v1", "v1beta1"]
    
    client_config {
      service {
        name      = "security-webhook"
        namespace = kubernetes_namespace.security_scanning.metadata[0].name
        path      = "/validate"
      }
      
      # In production, use proper CA bundle
      ca_bundle = base64encode("placeholder-ca-bundle")
    }
    
    rule {
      api_groups   = ["*"]
      api_versions = ["*"]
      operations   = ["DELETE"]
      resources    = ["*"]
      scope        = "Namespaced"
    }
    
    namespace_selector {
      match_labels = {
        "security.platform/critical" = "true"
      }
    }
    
    failure_policy = "Fail"
    side_effects   = "None"
    timeout_seconds = 10
  }
}

# MutatingWebhookConfiguration to add security labels
resource "kubernetes_mutating_webhook_configuration_v1" "security_labeler" {
  metadata {
    name   = "security-resource-labeler"
    labels = local.security_labels
  }

  webhook {
    name = "label-security-resources.security.platform"
    
    admission_review_versions = ["v1", "v1beta1"]
    
    client_config {
      service {
        name      = "security-webhook"
        namespace = kubernetes_namespace.security_scanning.metadata[0].name
        path      = "/mutate"
      }
      
      ca_bundle = base64encode("placeholder-ca-bundle")
    }
    
    rule {
      api_groups   = ["apps", "batch"]
      api_versions = ["v1"]
      operations   = ["CREATE", "UPDATE"]
      resources    = ["deployments", "daemonsets", "statefulsets", "jobs", "cronjobs"]
    }
    
    namespace_selector {
      match_labels = {
        "security.platform/scanning-enabled" = "true"
      }
    }
    
    failure_policy = "Ignore"  # Don't block deployments if webhook fails
    side_effects   = "None"
  }
}