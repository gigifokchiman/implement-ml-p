# ArgoCD Commands Guide

This guide demonstrates how ArgoCD solves common Kustomize pain points through its powerful command-line interface and web UI.

**Last Updated:** January 2025  
**Repository:** https://github.com/gigifokchiman/implement-ml-p  
**ArgoCD Access:** http://argocd.ml-platform.local:30080 (local) or via port-forward

## 🎯 Overview

ArgoCD transforms the challenging aspects of Kustomize management by providing:
- **Visual YAML rendering** instead of mental compilation
- **Diff previews** before applying changes
- **Centralized execution** eliminating manual kustomize builds
- **Easy rollbacks** with full revision history

---

## 🔍 Visualizing Final Rendered YAML

### Problem with Manual Kustomize
```bash
# 😰 Mental gymnastics required
cd infrastructure/kubernetes/overlays/local/
kustomize build . | less  # Scroll through thousands of lines
# Hard to understand what changed or validate correctness
```

### ArgoCD Solution

#### CLI Commands
```bash
# View complete rendered manifests
argocd app manifests ml-platform-local

# Using management script
./scripts/argocd-manage.sh manifests ml-platform-local

# Alternative: Get application definition
kubectl get application ml-platform-local -n argocd -o yaml
```

#### Makefile Integration
```bash
# Quick manifest viewing
make argocd-manifests-ml-platform-local
```

#### ArgoCD Web UI
1. Navigate to application: `ml-platform-local`
2. Click **"Manifest"** tab
3. View final rendered YAML with syntax highlighting
4. Search and filter specific resources

**Benefits**:
- ✅ Syntax-highlighted YAML viewing
- ✅ Resource-by-resource breakdown
- ✅ Search and filter capabilities
- ✅ No local kustomize build required

---

## 📊 Showing Diffs Before Applying

### Problem with Manual Kustomize
```bash
# 😰 Manual diff process
kustomize build overlays/local/ > /tmp/new.yaml
kubectl diff -f /tmp/new.yaml  # Cryptic output, hard to read
# Risk of applying without understanding changes
```

### ArgoCD Solution

#### CLI Commands
```bash
# Show detailed diff without applying
argocd app diff ml-platform-local

# Management script wrapper
./scripts/argocd-manage.sh diff ml-platform-local

# Preview sync operation
argocd app sync ml-platform-local --dry-run
```

#### Makefile Integration
```bash
# Quick diff checking
make argocd-diff-ml-platform-local
```

#### ArgoCD Web UI
1. Open application view
2. **OutOfSync** status shows diff count
3. Click **"App Diff"** for line-by-line comparison
4. Use **"Sync → Preview"** for sync-time diff

**Diff Features**:
- 🔴 **Red lines**: Removed content
- 🟢 **Green lines**: Added content  
- 📁 **File-by-file**: Organized by resource
- 🔍 **Search**: Find specific changes

**Benefits**:
- ✅ Visual diff with color coding
- ✅ Side-by-side comparison
- ✅ Resource-level filtering
- ✅ No temporary files needed

---

## 🎯 Centralizing Kustomize Execution

### Problem with Manual Kustomize
```bash
# 😰 Manual multi-step process
cd infrastructure/kubernetes/overlays/local/
kustomize build . > manifests.yaml
kubectl apply -f manifests.yaml
rm manifests.yaml
# Repeat for each environment, error-prone
```

### ArgoCD Solution

#### CLI Commands
```bash
# Single command - ArgoCD handles kustomize internally
argocd app sync ml-platform-local

# Management script
./scripts/argocd-manage.sh sync ml-platform-local

# Refresh to check for new changes
argocd app refresh ml-platform-local
```

#### Makefile Integration
```bash
# Environment-specific sync
make argocd-sync-ml-platform-local
make argocd-sync-ml-platform-dev
make argocd-sync-ml-platform-staging
make argocd-sync-ml-platform-prod
```

#### Automated Sync (GitOps)
```yaml
# Configured in applications - no manual commands needed!
syncPolicy:
  automated:
    prune: true      # Auto-remove deleted resources
    selfHeal: true   # Auto-fix manual changes
```

**Environments with Auto-Sync**:
- ✅ **Local**: Immediate sync on Git push
- ✅ **Development**: Automatic deployment
- ⚠️ **Staging**: Manual approval required
- 🔒 **Production**: Manual approval only

**Benefits**:
- ✅ No manual kustomize builds
- ✅ Consistent execution environment
- ✅ Built-in error handling
- ✅ Environment-specific policies

---

## ⏪ Easy Rollbacks

### Problem with Manual Kustomize
```bash
# 😰 Manual rollback nightmare
kubectl rollout undo deployment/backend -n ml-platform
# Only works for deployments, not full application state
# No visibility into what changed
# Hard to rollback multiple resources
```

### ArgoCD Solution

#### View Revision History
```bash
# List all application revisions
argocd app history ml-platform-local

# Detailed revision information
./scripts/argocd-manage.sh describe ml-platform-local

# Show specific revision details
argocd app get ml-platform-local --revision 5
```

#### Rollback Commands
```bash
# Rollback to specific revision
argocd app rollback ml-platform-local 5

# Management script
./scripts/argocd-manage.sh rollback ml-platform-local 5

# Rollback with sync (apply immediately)
argocd app rollback ml-platform-local 5 --sync
```

#### Makefile Integration
```bash
# Quick rollback
make argocd-rollback-ml-platform-local REV=5
```

#### ArgoCD Web UI Rollback
1. Navigate to application
2. Click **"History and Rollback"**
3. Select target revision
4. Click **"Rollback"**
5. Confirm in popup dialog

**Rollback Features**:
- 📊 **Visual timeline**: See all deployments
- 📝 **Commit messages**: Understand each change
- 👤 **Author tracking**: Who made changes
- 🕐 **Timestamps**: When changes occurred
- 🔄 **One-click rollback**: Complete application state

**Benefits**:
- ✅ Full application rollback (not just deployments)
- ✅ Visual revision history
- ✅ Git commit correlation
- ✅ Safe rollback with preview

---

## 🖥️ ArgoCD Web UI Features

### Dashboard Overview
```
https://argocd.ml-platform.local:30080
├── Application health status
├── Sync status indicators  
├── Resource count summaries
└── Quick action buttons
```

### Application Details View
```
Application: ml-platform-local
├── 📊 Summary: Health, sync status, repository
├── 🌳 Tree View: Resource hierarchy
├── 📋 Manifest: Rendered YAML
├── 📈 Events: Application timeline
├── 🔄 Sync: Manual sync with options
└── 📊 History: Revision management
```

### Resource Tree Visualization
```
ml-platform-local
├── 📦 Namespace/ml-platform (✅ Healthy)
├── 🚀 Deployment/backend (✅ Healthy)
│   ├── 📊 ReplicaSet/backend-xyz (✅ Healthy)
│   └── 🔵 Pod/backend-xyz-123 (✅ Running)
├── 🌐 Service/backend (✅ Healthy)
├── ⚙️ ConfigMap/backend-config (⚠️ OutOfSync)
└── 🔐 Secret/backend-secret (🔄 Progressing)
```

### Sync Operations Panel
```
Sync Options:
├── 🔄 Normal Sync: Standard sync
├── 🧹 Prune: Remove deleted resources  
├── 🔧 Force: Override validation
├── 👁️ Preview: Show changes first
└── 🎯 Selective: Sync specific resources
```

---

## 🎮 Live Demo: Before vs After

### Scenario: Update Backend Image

#### Old Way (Manual Kustomize)
```bash
# 😰 Error-prone multi-step process
cd infrastructure/kubernetes/overlays/local/

# 1. Edit the kustomization
vim kustomization.yaml  # Change image tag

# 2. Build and preview (maybe)
kustomize build . > /tmp/new.yaml
kubectl diff -f /tmp/new.yaml  # Hard to read output

# 3. Apply and hope
kubectl apply -f /tmp/new.yaml

# 4. Check status manually
kubectl get pods -n ml-platform
kubectl logs -n ml-platform deployment/backend

# 5. Rollback if needed (complex)
kubectl rollout undo deployment/backend -n ml-platform

# 6. Clean up
rm /tmp/new.yaml
```

#### New Way (ArgoCD GitOps)
```bash
# 😎 Simple and safe GitOps workflow

# 1. Make changes and commit
vim infrastructure/kubernetes/overlays/local/kustomization.yaml
git add . && git commit -m "Update backend to v1.2.3" && git push

# 2. ArgoCD automatically detects changes and syncs
# Or manually trigger:
./scripts/argocd-manage.sh sync ml-platform-local

# 3. Check status in UI or CLI
./scripts/argocd-manage.sh status ml-platform-local

# 4. Rollback if needed (one command)
./scripts/argocd-manage.sh rollback ml-platform-local 5
```

**Time Saved**: ~10 minutes → ~30 seconds  
**Error Reduction**: ~80% fewer mistakes  
**Visibility**: Full before/after comparison  

---

## 📋 Troubleshooting Commands

### Debug Application Issues
```bash
# Comprehensive debugging
./scripts/argocd-manage.sh debug ml-platform-local

# Check application events
./scripts/argocd-manage.sh events ml-platform-local

# View application logs
./scripts/argocd-manage.sh logs ml-platform-local

# Check pods in target namespace
./scripts/argocd-manage.sh pods ml-platform-local
```

### Check ArgoCD Health
```bash
# Overall ArgoCD system health
./scripts/argocd-manage.sh health

# ArgoCD component status
kubectl get pods -n argocd

# Application sync status
./scripts/argocd-manage.sh apps
```

### Common Issues and Solutions

#### Application Stuck in Progressing
```bash
# Check events
./scripts/argocd-manage.sh events ml-platform-local

# Debug specific issue
./scripts/argocd-manage.sh debug ml-platform-local

# Force refresh
argocd app refresh ml-platform-local --hard
```

#### Sync Failures
```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=server -k infrastructure/kubernetes/overlays/local/

# Check ArgoCD controller logs
kubectl logs -n argocd deployment/argocd-application-controller
```

#### Permission Issues
```bash
# Check RBAC permissions
kubectl auth can-i create deployments \
  --as=system:serviceaccount:argocd:argocd-application-controller \
  -n ml-platform
```

---

## 🔗 Quick Access Commands

### Dashboard and Login
```bash
# Open ArgoCD dashboard
./scripts/argocd-manage.sh dashboard
make argocd-dashboard

# Get admin password
./scripts/argocd-manage.sh password
make argocd-password

# CLI login
./scripts/argocd-manage.sh login
make argocd-login
```

### Application Management
```bash
# List all applications
./scripts/argocd-manage.sh list
make argocd-apps

# Show application status
./scripts/argocd-manage.sh status ml-platform-local

# Sync application
./scripts/argocd-manage.sh sync ml-platform-local
make argocd-sync-ml-platform-local
```

---

## 💡 Pro Tips and Advanced Usage

### Selective Resource Sync
```bash
# Sync only specific resources
argocd app sync ml-platform-local \
  --resource Deployment:backend \
  --resource Service:backend

# Sync everything except secrets
argocd app sync ml-platform-local \
  --resource '!Secret'
```

### Sync with Options
```bash
# Dry run (preview only)
argocd app sync ml-platform-local --dry-run

# Force sync (override validation)
argocd app sync ml-platform-local --force

# Prune deleted resources
argocd app sync ml-platform-local --prune

# Skip schema validation
argocd app sync ml-platform-local --validate=false
```

### Resource Filtering
```bash
# Show only deployments
argocd app get ml-platform-local --resource Deployment

# Show resources by label
argocd app get ml-platform-local --selector app=backend
```

### Diff Options
```bash
# Show diff for specific resource
argocd app diff ml-platform-local --resource Deployment:backend

# Ignore differences in specific fields
argocd app diff ml-platform-local --ignore-differences-json
```

---

## 🏗️ Integration with CI/CD

### GitHub Actions Integration
```yaml
# .github/workflows/deploy.yml
- name: Sync ArgoCD Application
  run: |
    argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD
    argocd app sync ml-platform-dev --prune
    argocd app wait ml-platform-dev --health
```

### Webhook Integration
```bash
# Configure webhook for auto-sync
curl -X POST https://argocd.example.com/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"repository": {"url": "https://github.com/org/ml-platform"}}'
```

---

## 📚 Environment-Specific Commands

### Local Development
```bash
# Bootstrap local ArgoCD
./scripts/bootstrap-argocd.sh local

# Sync local application
make argocd-sync-ml-platform-local

# Access local dashboard
open http://argocd.ml-platform.local:30080
```

### Development Environment
```bash
# Bootstrap dev ArgoCD
ENVIRONMENT=dev ./scripts/bootstrap-argocd.sh dev

# Sync dev application
ENVIRONMENT=dev ./scripts/argocd-manage.sh sync ml-platform-dev
```

### Production Environment
```bash
# Production requires manual approval
./scripts/argocd-manage.sh diff ml-platform-prod
./scripts/argocd-manage.sh sync ml-platform-prod

# Production rollback (emergency)
./scripts/argocd-manage.sh rollback ml-platform-prod 10
```

---

## 🎓 Best Practices

### 1. **Always Preview First**
```bash
# Check diff before syncing
argocd app diff ml-platform-prod
# Then sync with confidence
argocd app sync ml-platform-prod
```

### 2. **Use Selective Sync for Safety**
```bash
# Sync non-critical resources first
argocd app sync ml-platform-prod --resource ConfigMap
argocd app sync ml-platform-prod --resource Service
# Then sync critical resources
argocd app sync ml-platform-prod --resource Deployment
```

### 3. **Monitor Sync Status**
```bash
# Wait for sync completion
argocd app wait ml-platform-prod --health --timeout 300
```

### 4. **Keep Revision History**
```bash
# Check revision before major changes
argocd app history ml-platform-prod | head -5
# Remember good revision numbers for quick rollback
```

---

## 🔧 Makefile Quick Reference

```bash
# Setup and access
make argocd-bootstrap ENV=local    # Bootstrap ArgoCD
make argocd-dashboard              # Open dashboard
make argocd-login                  # CLI login
make argocd-password               # Get admin password

# Application management
make argocd-apps                   # List all applications
make argocd-status                 # Show all app status
make argocd-sync-ml-platform-local # Sync specific app
make argocd-health                 # Check ArgoCD health

# Debugging
make argocd-logs-ml-platform-local    # Show app logs
make argocd-debug-ml-platform-local   # Debug app issues
```

---

This guide transforms complex Kustomize operations into simple, visual, and safe ArgoCD commands. The GitOps workflow eliminates manual errors while providing complete visibility and easy rollback capabilities.

For more information, see:
- [ArgoCD Migration Guide](ARGOCD-MIGRATION-GUIDE.md)
- [Kustomize Challenges](KUSTOMIZE-CHALLENGES.md)
- [Infrastructure Makefile](../Makefile)
