# Platform Certificate Management Module
# Handles certificate management infrastructure using provider abstraction

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Cert-Manager Provider Module
module "kubernetes_cert_manager" {
  source = "../../providers/kubernetes/cert-manager"

  config = {
    enable_cert_manager  = var.config.enable_cert_manager
    cert_manager_version = var.config.cert_manager_version
  }

  tags = var.tags
}

# ClusterIssuer for Let's Encrypt (production clusters)
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.config.enable_cert_manager && var.config.enable_letsencrypt_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "letsencrypt-prod"
      labels = var.tags
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [module.kubernetes_cert_manager]
}

# Self-signed issuer for local development
resource "kubernetes_manifest" "selfsigned_issuer" {
  count = var.config.enable_cert_manager && var.config.enable_selfsigned_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "selfsigned"
      labels = var.tags
    }
    spec = {
      selfSigned = {}
    }
  }

  depends_on = [module.kubernetes_cert_manager]
}

