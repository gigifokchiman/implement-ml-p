# ArgoCD Migration Guide

This guide explains how to migrate from manual Kustomize deployments to ArgoCD GitOps workflow.

## 🎯 Overview

**Before (Manual)**: `kubectl apply -k overlays/local/`
**After (GitOps)**: Git push → ArgoCD automatically syncs

## 📋 Migration Steps

### 1. **Bootstrap ArgoCD**

```bash
# Install ArgoCD for local development
./scripts/bootstrap-argocd.sh local

# For other environments
./scripts/bootstrap-argocd.sh dev
./scripts/bootstrap-argocd.sh staging
./scripts/bootstrap-argocd.sh prod
```

### 2. **Update Repository URL**

Edit the application manifests to point to your actual repository:

```bash
# Update all applications with your repo URL
export REPO_URL="https://github.com/your-org/ml-platform"

find infrastructure/kubernetes/base/gitops/applications/ -name "*.yaml" -not -name "kustomization.yaml" -exec \
  sed -i "s|https://github.com/your-org/ml-platform|$REPO_URL|g" {} \;
```

### 3. **Access ArgoCD Dashboard**

```bash
# Get admin password
./scripts/argocd-manage.sh password

# Open dashboard
./scripts/argocd-manage.sh dashboard

# Or port-forward (alternative)
kubectl port-forward -n argocd svc/argocd-server 8080:80
# Access: http://localhost:8080
```

### 4. **Verify Applications**

```bash
# List all applications
./scripts/argocd-manage.sh list

# Check specific application
./scripts/argocd-manage.sh status ml-platform-local

# View all apps status
./scripts/argocd-manage.sh apps
```

### 5. **Sync Applications**

```bash
# Manual sync (first time)
./scripts/argocd-manage.sh sync ml-platform-local

# Auto-sync is enabled, so future changes will sync automatically
```

## 🔄 New Workflow

### Development Workflow

**Old Way**:
```bash
# Edit Kubernetes manifests
vim kubernetes/overlays/local/kustomization.yaml

# Manual apply
kubectl apply -k kubernetes/overlays/local/

# Check status
kubectl get pods -n ml-platform
```

**New Way**:
```bash
# Edit Kubernetes manifests
vim kubernetes/overlays/local/kustomization.yaml

# Commit and push
git add . && git commit -m "Update local config" && git push

# ArgoCD automatically syncs changes
# Check status in ArgoCD UI or:
./scripts/argocd-manage.sh status ml-platform-local
```

### Production Workflow

**Old Way**:
```bash
# Manual production deployment (risky!)
kubectl apply -k kubernetes/overlays/prod/
```

**New Way**:
```bash
# Production uses manual sync for safety
git push  # Push changes

# Review in ArgoCD UI
./scripts/argocd-manage.sh dashboard

# Manual approval in UI or:
./scripts/argocd-manage.sh sync ml-platform-prod
```

## 📊 Key Differences

| Aspect | Manual Kustomize | ArgoCD GitOps |
|--------|------------------|---------------|
| **Deployment** | `kubectl apply -k` | Git push |
| **Status** | `kubectl get pods` | ArgoCD UI |
| **Rollback** | Manual `kubectl` | One-click UI |
| **History** | Git history only | Git + ArgoCD history |
| **Multi-env** | Multiple commands | Single UI |
| **Drift detection** | Manual check | Automatic detection |
| **Sync status** | Unknown | Visual in UI |

## 🛠️ Management Commands

### Application Management
```bash
# List applications
./scripts/argocd-manage.sh list

# Sync application  
./scripts/argocd-manage.sh sync <app-name>

# Check status
./scripts/argocd-manage.sh status <app-name>

# View logs
./scripts/argocd-manage.sh logs <app-name>

# Rollback
./scripts/argocd-manage.sh rollback <app-name> <revision>
```

### Troubleshooting
```bash
# Debug application
./scripts/argocd-manage.sh debug <app-name>

# View events
./scripts/argocd-manage.sh events <app-name>

# Check ArgoCD health
./scripts/argocd-manage.sh health

# ArgoCD CLI login
./scripts/argocd-manage.sh login
```

## 🔧 Configuration Changes

### Environment-Specific Settings

**Local Environment**:
- Auto-sync enabled
- Insecure mode (no TLS)
- NodePort service (port 30080)

**Development Environment**:
- Auto-sync enabled
- Self-heal enabled
- LoadBalancer or Ingress

**Staging Environment**:
- Manual sync (for approval)
- Self-heal enabled
- Extended revision history

**Production Environment**:
- Manual sync only
- No self-heal
- Extensive revision history
- Notifications enabled

### Application Sync Policies

```yaml
# Local/Dev: Automated
syncPolicy:
  automated:
    prune: true
    selfHeal: true

# Staging: Semi-automated  
syncPolicy:
  automated:
    prune: false  # Manual approval for pruning
    selfHeal: true

# Production: Manual only
syncPolicy:
  automated:
    prune: false
    selfHeal: false  # No automatic changes
```

## 📱 ArgoCD UI Features

### Dashboard Overview
- Application health status
- Sync status and history
- Resource tree visualization
- Live resource state

### Application Details
- YAML diff viewer
- Resource dependency graph
- Event timeline
- Sync options

### Operations
- One-click sync
- Selective resource sync
- Rollback to any revision
- Manual override parameters

## 🚨 Migration Gotchas

### 1. **Repository Access**
ArgoCD needs access to your Git repository:
```bash
# For private repos, configure SSH key or token
kubectl create secret generic git-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/your-org/ml-platform \
  --from-literal=password=your-token \
  -n argocd
```

### 2. **RBAC Permissions**
ArgoCD needs cluster permissions:
```bash
# Check ArgoCD has required permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:argocd:argocd-application-controller
```

### 3. **Kustomize Versions**
Ensure ArgoCD uses compatible Kustomize version:
```yaml
# ArgoCD ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
data:
  kustomize.version: v4.5.7
```

### 4. **Sync Waves**
Use sync waves for deployment order:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
```

### 5. **Resource Hooks**
Use hooks for pre/post deployment tasks:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

## 🔄 Rollback Strategy

### Before ArgoCD
```bash
# Manual rollback (error-prone)
kubectl rollout undo deployment/backend -n ml-platform
```

### With ArgoCD
```bash
# List revisions
./scripts/argocd-manage.sh describe ml-platform-local

# Rollback to specific revision
./scripts/argocd-manage.sh rollback ml-platform-local 5

# Or use UI for visual rollback
./scripts/argocd-manage.sh dashboard
```

## 📊 Monitoring and Alerts

### ArgoCD Notifications
Configure Slack/email notifications:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: Application {{.app.metadata.name}} is now running new version.
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

### Prometheus Metrics
ArgoCD exposes metrics for monitoring:
- Application sync status
- Sync duration
- Resource health
- API response times

## 🎓 Best Practices

### 1. **Git Repository Structure**
Keep clear separation:
```
infrastructure/
├── kubernetes/
│   ├── base/           # Shared base configs
│   └── overlays/       # Environment-specific
└── terraform/          # Infrastructure as Code
```

### 2. **Application Organization**
- One application per environment
- Use sync waves for dependencies
- Group related resources

### 3. **Security**
- Use least-privilege RBAC
- Scan container images
- Validate Kubernetes manifests

### 4. **Testing**
- Test changes in lower environments first
- Use preview environments for features
- Validate with dry-run

## 📝 Archived Scripts

The following scripts are now primarily for reference:

**Archived (but kept for reference)**:
- `deploy-local.sh` - Now replaced by ArgoCD
- `deploy.sh` - For manual deployments if needed
- Manual `kubectl apply` commands

**Still Active**:
- `tf-wrapper.sh` - Terraform operations
- `docker-infra.sh` - Docker-based tools
- `bootstrap-argocd.sh` - ArgoCD installation
- `argocd-manage.sh` - ArgoCD operations

## 🆘 Troubleshooting

### Common Issues

**Application Stuck in Progressing**:
```bash
./scripts/argocd-manage.sh debug ml-platform-local
./scripts/argocd-manage.sh events ml-platform-local
```

**Sync Failures**:
```bash
# Check resource validation
kubectl apply --dry-run=server -k infrastructure/kubernetes/overlays/local/

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

**Permission Issues**:
```bash
# Check RBAC
kubectl auth can-i create deployments --as=system:serviceaccount:argocd:argocd-application-controller -n ml-platform
```

**Repository Access**:
```bash
# Test repository access
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote https://github.com/your-org/ml-platform
```

## 🚀 Next Steps

After successful migration:

1. **Set up monitoring** - Configure alerts for sync failures
2. **Train the team** - ArgoCD UI and CLI usage
3. **Configure RBAC** - Team-specific access controls
4. **Set up notifications** - Slack/email integration
5. **Implement progressive deployment** - Canary deployments
6. **Add compliance** - Policy enforcement with OPA

The migration to ArgoCD provides better visibility, safety, and automation for your ML Platform deployments!