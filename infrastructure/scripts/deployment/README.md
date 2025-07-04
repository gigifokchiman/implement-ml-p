# Deployment Scripts

Core deployment scripts for setting up the ML platform infrastructure.

## Scripts

- **`deploy-local.sh`** - Main local platform deployment (Kind cluster + services)
- **`deploy-argocd.sh`** - Deploy ArgoCD GitOps engine with Prometheus stack
- **`setup-argocd-apps.sh`** - Configure ArgoCD applications for team monitoring
- **`deploy-new-app.sh`** - Deploy new applications using the platform template

## Usage Order

1. `deploy-local.sh --clean-first` - Set up base platform
2. `deploy-argocd.sh` - Add GitOps capabilities
3. `setup-argocd-apps.sh` - Configure GitOps applications
4. `deploy-new-app.sh <app-name>` - Deploy your applications

These scripts form the core deployment workflow documented in the New Engineer Runbook.
