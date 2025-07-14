# AWS Provider Cluster Module - Provider Version Constraints
# This module implements EKS cluster functionality

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # AWS provider - main provider for EKS
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Kubernetes provider for post-cluster configuration
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }

    # Helm provider for installing cluster add-ons
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }

    # TLS provider for certificate generation
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # Random provider for generating secure values
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    # Time provider for timing dependencies
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}