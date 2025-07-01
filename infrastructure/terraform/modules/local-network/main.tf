# Local Network Simulation Module
# Simulates AWS VPC behavior using Kubernetes namespaces and NetworkPolicies

locals {
  name_prefix = var.name_prefix

  # Simulate VPC subnets using Kubernetes namespaces
  subnets = {
    # Public subnet equivalent - services with ingress access
    public = {
      name = "${local.name_prefix}-public"
      labels = {
        "network.ml-platform/subnet-type"     = "public"
        "network.ml-platform/internet-access" = "true"
        "network.ml-platform/ingress-allowed" = "true"
      }
      allow_ingress  = true
      allow_internet = true
    }

    # Private subnet equivalent - internal services
    private = {
      name = "${local.name_prefix}-private"
      labels = {
        "network.ml-platform/subnet-type"     = "private"
        "network.ml-platform/internet-access" = "false"
        "network.ml-platform/ingress-allowed" = "false"
      }
      allow_ingress  = false
      allow_internet = false
    }

    # Database subnet equivalent - data layer
    database = {
      name = "${local.name_prefix}-database"
      labels = {
        "network.ml-platform/subnet-type"     = "database"
        "network.ml-platform/internet-access" = "false"
        "network.ml-platform/ingress-allowed" = "false"
        "network.ml-platform/data-layer"      = "true"
      }
      allow_ingress  = false
      allow_internet = false
    }

    # ML workload subnet - compute-intensive tasks
    ml-workload = {
      name = "${local.name_prefix}-ml-workload"
      labels = {
        "network.ml-platform/subnet-type"     = "ml-workload"
        "network.ml-platform/internet-access" = "true"
        "network.ml-platform/ingress-allowed" = "false"
        "network.ml-platform/workload-type"   = "ml"
      }
      allow_ingress  = false
      allow_internet = true # For downloading models, datasets
    }

    # Data processing subnet - ETL and batch jobs
    data-processing = {
      name = "${local.name_prefix}-data-processing"
      labels = {
        "network.ml-platform/subnet-type"     = "data-processing"
        "network.ml-platform/internet-access" = "true"
        "network.ml-platform/ingress-allowed" = "false"
        "network.ml-platform/workload-type"   = "data"
      }
      allow_ingress  = false
      allow_internet = true # For external data sources
    }

    # Monitoring subnet - observability stack
    monitoring = {
      name = "${local.name_prefix}-monitoring"
      labels = {
        "network.ml-platform/subnet-type"     = "monitoring"
        "network.ml-platform/internet-access" = "false"
        "network.ml-platform/ingress-allowed" = "true"
        "network.ml-platform/observability"   = "true"
      }
      allow_ingress  = true # For accessing dashboards
      allow_internet = false
    }
  }
}

# Create namespace-based "subnets"
resource "kubernetes_namespace" "subnets" {
  for_each = local.subnets

  metadata {
    name = each.value.name
    labels = merge(
      each.value.labels,
      {
        "network.ml-platform/managed-by"     = "terraform"
        "network.ml-platform/vpc-simulation" = "true"
      }
    )

    annotations = {
      "network.ml-platform/description"    = "Simulated ${each.key} subnet for local VPC-like behavior"
      "network.ml-platform/allow-ingress"  = tostring(each.value.allow_ingress)
      "network.ml-platform/allow-internet" = tostring(each.value.allow_internet)
    }
  }
}

# Default deny-all network policy for each subnet
resource "kubernetes_network_policy" "subnet_default_deny" {
  for_each = local.subnets

  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.subnets[each.key].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "default-deny"
      "network.ml-platform/subnet"      = each.key
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    # No rules = deny all
  }
}

# Allow DNS for all pods (simulates VPC DNS)
resource "kubernetes_network_policy" "allow_dns" {
  for_each = local.subnets

  metadata {
    name      = "allow-dns"
    namespace = kubernetes_namespace.subnets[each.key].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "allow-dns"
      "network.ml-platform/subnet"      = each.key
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }
  }
}

# Internet access policy (simulates NAT Gateway/Internet Gateway)
resource "kubernetes_network_policy" "allow_internet" {
  for_each = { for k, v in local.subnets : k => v if v.allow_internet }

  metadata {
    name      = "allow-internet"
    namespace = kubernetes_namespace.subnets[each.key].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "allow-internet"
      "network.ml-platform/subnet"      = each.key
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      # Allow external traffic (simulates Internet Gateway)
      to {}

      # But only on standard ports
      ports {
        port     = "80"
        protocol = "TCP"
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }
  }
}

# Cross-subnet communication rules (simulates VPC route tables)
# Public subnet can communicate with private subnet
resource "kubernetes_network_policy" "public_to_private" {
  metadata {
    name      = "allow-public-to-private"
    namespace = kubernetes_namespace.subnets["private"].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "cross-subnet"
      "network.ml-platform/direction"   = "public-to-private"
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "network.ml-platform/subnet-type" = "public"
          }
        }
      }
    }
  }
}

# Private subnet can communicate with database subnet
resource "kubernetes_network_policy" "private_to_database" {
  metadata {
    name      = "allow-private-to-database"
    namespace = kubernetes_namespace.subnets["database"].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "cross-subnet"
      "network.ml-platform/direction"   = "private-to-database"
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "network.ml-platform/subnet-type" = "private"
          }
        }
      }
    }
  }
}

# ML workload subnet can communicate with data processing and database
resource "kubernetes_network_policy" "ml_workload_access" {
  metadata {
    name      = "allow-ml-workload-access"
    namespace = kubernetes_namespace.subnets["database"].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "cross-subnet"
      "network.ml-platform/direction"   = "ml-workload-to-database"
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "network.ml-platform/subnet-type" = "ml-workload"
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy" "data_processing_access" {
  metadata {
    name      = "allow-data-processing-access"
    namespace = kubernetes_namespace.subnets["database"].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "cross-subnet"
      "network.ml-platform/direction"   = "data-processing-to-database"
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "network.ml-platform/subnet-type" = "data-processing"
          }
        }
      }
    }
  }
}

# Monitoring subnet can access all other subnets for metrics collection
resource "kubernetes_network_policy" "monitoring_access" {
  for_each = { for k, v in local.subnets : k => v if k != "monitoring" }

  metadata {
    name      = "allow-monitoring-access"
    namespace = kubernetes_namespace.subnets[each.key].metadata[0].name
    labels = {
      "network.ml-platform/policy-type" = "cross-subnet"
      "network.ml-platform/direction"   = "monitoring-to-${each.key}"
    }
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "network.ml-platform/subnet-type" = "monitoring"
          }
        }
      }

      # Common monitoring ports
      ports {
        port     = "9090" # Prometheus
        protocol = "TCP"
      }
      ports {
        port     = "8080" # Metrics endpoints
        protocol = "TCP"
      }
      ports {
        port     = "3000" # Grafana
        protocol = "TCP"
      }
    }
  }
}

# Node selectors and taints simulation (simulates AZ placement)
resource "kubernetes_config_map" "subnet_node_affinity" {
  for_each = local.subnets

  metadata {
    name      = "${each.key}-node-affinity"
    namespace = kubernetes_namespace.subnets[each.key].metadata[0].name
    labels = {
      "network.ml-platform/config-type" = "node-affinity"
      "network.ml-platform/subnet"      = each.key
    }
  }

  data = {
    "node-selector" = jsonencode({
      "ml-platform/subnet-preference" = each.key
    })

    "affinity-rules" = jsonencode({
      nodeAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            preference = {
              matchExpressions = [
                {
                  key      = "ml-platform/workload-type"
                  operator = "In"
                  values   = [each.key]
                }
              ]
            }
          }
        ]
      }
    })

    "tolerations" = jsonencode([
      {
        key      = "ml-platform/subnet"
        value    = each.key
        operator = "Equal"
        effect   = "NoSchedule"
      }
    ])
  }
}