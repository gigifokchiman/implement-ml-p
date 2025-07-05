# Platform Security Bootstrap Interface
# Orchestrates security infrastructure using dependency injection

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Cross-cutting concerns
module "cross_cutting" {
  source = "../../shared/cross-cutting"
  
  platform_name     = "data-platform"
  environment       = var.environment != null ? var.environment : "unknown"
  module_name       = "security-bootstrap"
  service_name      = var.name
  component_type    = "security"
  service_type      = "infrastructure"
  service_tier      = "core"
  security_level    = "high"
  namespace         = "default"
  
  base_tags = var.tags
}

# Certificate Management Module (dependency injected)
module "certificate_management" {
  source = "../certificate-management"
  
  config = {
    enable_cert_manager        = var.config.enable_cert_manager
    enable_letsencrypt_issuer = var.config.enable_letsencrypt_issuer
    enable_selfsigned_issuer  = var.config.enable_selfsigned_issuer
    cert_manager_version      = var.config.cert_manager_version
  }
  
  letsencrypt_email = var.letsencrypt_email
  tags             = module.cross_cutting.standard_tags
}

# Ingress Controller Module (dependency injected)
module "ingress_controller" {
  source = "../ingress-controller"
  
  config = {
    enable_nginx_ingress = true
    service_type        = var.config.ingress_service_type
    host_port_enabled   = var.config.ingress_host_port_enabled
  }
  
  tags = module.cross_cutting.standard_tags
}

# GitOps Module (dependency injected)
module "gitops" {
  source = "../gitops"
  
  config = {
    enable_argocd    = var.config.enable_argocd
    argocd_version   = var.config.argocd_version
    service_type     = var.config.argocd_service_type
    insecure         = var.config.argocd_insecure
  }
  
  tags = module.cross_cutting.standard_tags
  
  # Conditional deployment based on config
  count = var.config.enable_argocd ? 1 : 0
}

# Pod Security Standards using modern namespace labels (if enabled)
resource "kubernetes_labels" "pod_security_standards" {
  count = var.config.enable_pod_security ? 1 : 0
  
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "default"
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = var.config.pod_security_standard
    "pod-security.kubernetes.io/audit"   = var.config.pod_security_standard
    "pod-security.kubernetes.io/warn"    = var.config.pod_security_standard
  }
}

# Infrastructure-level default deny-all NetworkPolicy
resource "kubernetes_network_policy" "default_deny_all" {
  count = var.config.enable_network_policies ? 1 : 0

  metadata {
    name      = "default-deny-all"
    namespace = "default"
    labels    = var.tags
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

# Application-specific RBAC removed - handled by ArgoCD GitOps
# Infrastructure RBAC (cert-manager, ingress) is handled by Helm charts

# Output configuration (dependency injection safe)
locals {
  security_bootstrap_info = {
    cert_manager_enabled     = module.certificate_management.cert_manager_enabled
    cert_manager_namespace   = module.certificate_management.cert_manager_namespace
    cluster_issuer          = module.certificate_management.cluster_issuer
    ingress_class           = module.ingress_controller.ingress_class
    ingress_namespace       = module.ingress_controller.ingress_namespace
    argocd_enabled          = length(module.gitops) > 0 ? module.gitops[0].argocd_enabled : false
    argocd_namespace        = length(module.gitops) > 0 ? module.gitops[0].argocd_namespace : null
    pod_security_enabled    = var.config.enable_pod_security
    network_policies_enabled = var.config.enable_network_policies
    rbac_enabled            = var.config.enable_rbac
  }
}