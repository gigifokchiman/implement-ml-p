# Platform Cluster Module - Provider Version Constraints
# This module provides a provider-agnostic interface for cluster management

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # AWS provider for EKS clusters
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Kubernetes provider for cluster configuration
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }

    # Helm provider for application deployment
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }

    # Random provider for generating passwords and tokens
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    # TLS provider for certificate generation
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # Time provider for resource timing
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}