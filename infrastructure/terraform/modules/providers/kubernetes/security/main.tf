# Kubernetes Security Implementation
# Network Policies, Pod Security Standards, and Admission Control

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

# Pod Security Standards
resource "kubernetes_labels" "namespace_security" {
  count = var.config.enable_pod_security ? length(var.namespaces) : 0

  api_version = "v1"
  kind        = "Namespace"

  metadata {
    name = var.namespaces[count.index]
  }

  labels = {
    "pod-security.kubernetes.io/enforce" = var.config.pod_security_standard
    "pod-security.kubernetes.io/audit"   = var.config.pod_security_standard
    "pod-security.kubernetes.io/warn"    = var.config.pod_security_standard
  }
}

# Network Policy: Deny all traffic by default
resource "kubernetes_network_policy" "deny_all" {
  count = var.config.enable_network_policies ? length(var.namespaces) : 0

  metadata {
    name      = "deny-all"
    namespace = var.namespaces[count.index]
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "network-policy"
      "app.kubernetes.io/component" = "security"
    })
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

# Network Policy: Allow database access from cache and storage
resource "kubernetes_network_policy" "database_access" {
  count = var.config.enable_network_policies ? 1 : 0

  metadata {
    name      = "allow-database-access"
    namespace = "database"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "network-policy"
      "app.kubernetes.io/component" = "security"
    })
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgres"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "cache"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "storage"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "monitoring"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }
  }
}

# Network Policy: Allow cache access from applications
resource "kubernetes_network_policy" "cache_access" {
  count = var.config.enable_network_policies ? 1 : 0

  metadata {
    name      = "allow-cache-access"
    namespace = "cache"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "network-policy"
      "app.kubernetes.io/component" = "security"
    })
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "redis"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "storage"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "monitoring"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "6379"
      }
    }
  }
}

# Network Policy: Allow storage access from applications
resource "kubernetes_network_policy" "storage_access" {
  count = var.config.enable_network_policies ? 1 : 0

  metadata {
    name      = "allow-storage-access"
    namespace = "storage"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "network-policy"
      "app.kubernetes.io/component" = "security"
    })
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "minio"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "app.kubernetes.io/name" = "monitoring"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "9000"
      }
    }
  }
}

# Network Policy: Allow monitoring to scrape all services
resource "kubernetes_network_policy" "monitoring_scrape" {
  count = var.config.enable_network_policies ? 1 : 0

  metadata {
    name      = "allow-monitoring-scrape"
    namespace = "monitoring"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "network-policy"
      "app.kubernetes.io/component" = "security"
    })
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {}
      }

      ports {
        protocol = "TCP"
        port     = "5432" # Database
      }
      ports {
        protocol = "TCP"
        port     = "6379" # Cache
      }
      ports {
        protocol = "TCP"
        port     = "9000" # Storage
      }
      ports {
        protocol = "TCP"
        port     = "8080" # Application metrics
      }
    }
  }
}

# Network Policy: Allow DNS resolution
resource "kubernetes_network_policy" "allow_dns" {
  count = var.config.enable_network_policies ? length(var.namespaces) : 0

  metadata {
    name      = "allow-dns"
    namespace = var.namespaces[count.index]
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "network-policy"
      "app.kubernetes.io/component" = "security"
    })
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            "name" = "kube-system"
          }
        }
      }

      ports {
        protocol = "UDP"
        port     = "53"
      }
      ports {
        protocol = "TCP"
        port     = "53"
      }
    }
  }
}