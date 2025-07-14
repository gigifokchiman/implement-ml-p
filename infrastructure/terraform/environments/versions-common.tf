# Common provider versions for all environments
# This file is symlinked or copied to each environment directory

terraform {
  required_version = local.terraform_version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = local.provider_versions.aws
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = local.provider_versions.kubernetes
    }
    helm = {
      source  = "hashicorp/helm"
      version = local.provider_versions.helm
    }
    random = {
      source  = "hashicorp/random"
      version = local.provider_versions.random
    }
    null = {
      source  = "hashicorp/null"
      version = local.provider_versions.null
    }
    time = {
      source  = "hashicorp/time"
      version = local.provider_versions.time
    }
    tls = {
      source  = "hashicorp/tls"
      version = local.provider_versions.tls
    }
    local = {
      source  = "hashicorp/local"
      version = local.provider_versions.local
    }
    external = {
      source  = "hashicorp/external"
      version = local.provider_versions.external
    }
    archive = {
      source  = "hashicorp/archive"
      version = local.provider_versions.archive
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = local.provider_versions.cloudinit
    }
  }
}