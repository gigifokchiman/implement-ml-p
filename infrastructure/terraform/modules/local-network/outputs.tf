# Local Network Simulation Module Outputs

output "vpc_simulation" {
  description = "VPC simulation details"
  value = {
    name         = "${var.name_prefix}-vpc-simulation"
    environment  = var.environment
    cluster_name = var.cluster_name
    subnet_count = length(local.subnets)
    policy_count = length(kubernetes_network_policy.subnet_default_deny) + length(kubernetes_network_policy.allow_dns) + length(kubernetes_network_policy.allow_internet) + 4
  }
}

output "subnets" {
  description = "Created subnet namespaces and their configurations"
  value = {
    for k, v in local.subnets : k => {
      namespace_name = kubernetes_namespace.subnets[k].metadata[0].name
      labels         = v.labels
      allow_ingress  = v.allow_ingress
      allow_internet = v.allow_internet
      description    = "Simulated ${k} subnet for VPC-like behavior in Kind"
    }
  }
}

output "network_policies" {
  description = "Network policies implementing VPC-like behavior"
  value = {
    default_deny_policies = {
      for k, v in kubernetes_network_policy.subnet_default_deny : k => {
        name      = v.metadata[0].name
        namespace = v.metadata[0].namespace
        type      = "default-deny-all"
      }
    }

    dns_policies = {
      for k, v in kubernetes_network_policy.allow_dns : k => {
        name      = v.metadata[0].name
        namespace = v.metadata[0].namespace
        type      = "allow-dns"
      }
    }

    internet_policies = {
      for k, v in kubernetes_network_policy.allow_internet : k => {
        name      = v.metadata[0].name
        namespace = v.metadata[0].namespace
        type      = "allow-internet"
      }
    }

    cross_subnet_policies = [
      {
        name        = kubernetes_network_policy.public_to_private.metadata[0].name
        namespace   = kubernetes_network_policy.public_to_private.metadata[0].namespace
        type        = "cross-subnet"
        direction   = "public-to-private"
        description = "Allows public subnet to communicate with private subnet"
      },
      {
        name        = kubernetes_network_policy.private_to_database.metadata[0].name
        namespace   = kubernetes_network_policy.private_to_database.metadata[0].namespace
        type        = "cross-subnet"
        direction   = "private-to-database"
        description = "Allows private subnet to communicate with database subnet"
      },
      {
        name        = kubernetes_network_policy.ml_workload_access.metadata[0].name
        namespace   = kubernetes_network_policy.ml_workload_access.metadata[0].namespace
        type        = "cross-subnet"
        direction   = "ml-workload-to-database"
        description = "Allows ML workload subnet to access database subnet"
      },
      {
        name        = kubernetes_network_policy.data_processing_access.metadata[0].name
        namespace   = kubernetes_network_policy.data_processing_access.metadata[0].namespace
        type        = "cross-subnet"
        direction   = "data-processing-to-database"
        description = "Allows data processing subnet to access database subnet"
      }
    ]
  }
}

output "subnet_namespaces" {
  description = "Map of subnet types to namespace names"
  value = {
    for k, v in kubernetes_namespace.subnets : k => v.metadata[0].name
  }
}

output "subnet_deployment_guide" {
  description = "Guide for deploying services to appropriate subnets"
  value = {
    public_subnet = {
      namespace   = kubernetes_namespace.subnets["public"].metadata[0].name
      use_for     = ["frontend", "api-gateway", "ingress-controllers"]
      description = "Services that need external access"
    }

    private_subnet = {
      namespace   = kubernetes_namespace.subnets["private"].metadata[0].name
      use_for     = ["backend-api", "web-services", "application-services"]
      description = "Internal application services"
    }

    database_subnet = {
      namespace   = kubernetes_namespace.subnets["database"].metadata[0].name
      use_for     = ["postgresql", "redis", "databases"]
      description = "Data storage and caching services"
    }

    ml_workload_subnet = {
      namespace   = kubernetes_namespace.subnets["ml-workload"].metadata[0].name
      use_for     = ["training-jobs", "inference-services", "model-servers"]
      description = "Machine learning compute workloads"
    }

    data_processing_subnet = {
      namespace   = kubernetes_namespace.subnets["data-processing"].metadata[0].name
      use_for     = ["etl-jobs", "data-pipelines", "batch-processing"]
      description = "Data processing and ETL workloads"
    }

    monitoring_subnet = {
      namespace   = kubernetes_namespace.subnets["monitoring"].metadata[0].name
      use_for     = ["prometheus", "grafana", "alertmanager", "logging"]
      description = "Monitoring and observability stack"
    }
  }
}

output "vpc_comparison" {
  description = "Comparison between AWS VPC and local simulation"
  value = {
    aws_vpc_features = {
      vpc_cidr           = "10.0.0.0/16 (configurable)"
      public_subnets     = "Internet Gateway access"
      private_subnets    = "NAT Gateway for outbound"
      database_subnets   = "No internet access"
      security_groups    = "Instance-level firewall"
      nacls              = "Subnet-level firewall"
      route_tables       = "Traffic routing control"
      availability_zones = "Multi-AZ deployment"
    }

    local_simulation = {
      vpc_equivalent    = "Kind cluster network"
      subnet_equivalent = "Kubernetes namespaces with labels"
      security_groups   = "NetworkPolicies (pod-level)"
      nacls_equivalent  = "Namespace-level NetworkPolicies"
      route_tables      = "Cross-namespace communication policies"
      az_simulation     = "Node affinity and taints"
      internet_gateway  = "Internet access NetworkPolicies"
      nat_gateway       = "Selective internet access per subnet"
    }
  }
}

output "useful_commands" {
  description = "Useful kubectl commands for managing the VPC simulation"
  value = {
    list_subnets = "kubectl get namespaces -l network.ml-platform/vpc-simulation=true"

    view_subnet_config = "kubectl get namespace ${kubernetes_namespace.subnets["public"].metadata[0].name} -o yaml"

    list_network_policies = "kubectl get networkpolicies --all-namespaces -l network.ml-platform/managed-by=terraform"

    deploy_to_public = "kubectl apply -f your-app.yaml -n ${kubernetes_namespace.subnets["public"].metadata[0].name}"

    deploy_to_private = "kubectl apply -f your-app.yaml -n ${kubernetes_namespace.subnets["private"].metadata[0].name}"

    deploy_to_database = "kubectl apply -f your-db.yaml -n ${kubernetes_namespace.subnets["database"].metadata[0].name}"

    check_connectivity = "kubectl exec -it pod-name -n ${kubernetes_namespace.subnets["public"].metadata[0].name} -- curl service-name.${kubernetes_namespace.subnets["private"].metadata[0].name}.svc.cluster.local"

    view_network_flow = "kubectl describe networkpolicy -n NAMESPACE-NAME"
  }
}