# RBAC for Security Scanning - Managed by Terraform
# These roles cannot be modified by teams

# Service account for security scanners
resource "kubernetes_service_account" "security_scanner" {
  metadata {
    name      = "security-scanner"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
    
    annotations = {
      "security.platform/purpose" = "Cluster-wide security scanning"
    }
  }
}

# ClusterRole for security scanning
resource "kubernetes_cluster_role" "security_scanner" {
  metadata {
    name   = "${var.name}-scanner"
    labels = local.security_labels
  }

  # Read access to all resources for scanning
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  # Write access for scan results
  rule {
    api_groups = ["security.scanner.io"]
    resources  = ["vulnerabilityreports", "configauditreports", "compliancereports"]
    verbs      = ["create", "update", "patch", "delete"]
  }
}

# ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "security_scanner" {
  metadata {
    name   = "${var.name}-scanner"
    labels = local.security_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.security_scanner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.security_scanner.metadata[0].name
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
  }
}

# Role for ArgoCD to manage deployments in security namespace
resource "kubernetes_role" "argocd_security_manager" {
  metadata {
    name      = "argocd-security-manager"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# RoleBinding for ArgoCD
resource "kubernetes_role_binding" "argocd_security_manager" {
  metadata {
    name      = "argocd-security-manager"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels    = local.security_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argocd_security_manager.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = "argocd"
  }
}