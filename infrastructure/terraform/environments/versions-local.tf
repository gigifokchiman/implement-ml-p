# Local environment specific providers
# Additional providers needed only for local development

terraform {
  required_providers {
    # Local development providers
    kind = {
      source  = "kind.local/gigifokchiman/kind"
      version = local.local_providers.kind
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = local.local_providers.docker
    }
  }
}