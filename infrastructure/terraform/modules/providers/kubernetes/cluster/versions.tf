# Kubernetes Provider Cluster Module - Provider Version Constraints
# This module implements Kind cluster functionality for local development

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # Kind provider for local cluster management
    # Note: This is a custom provider source specific to gigifokchiman
    kind = {
      source  = "kind.local/gigifokchiman/kind"
      version = ">= 0.1.4, < 1.0"
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

    # Random provider for generating values
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    # Null provider for resource dependencies
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    # Local provider for file operations
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }

    # Docker provider for container management
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}