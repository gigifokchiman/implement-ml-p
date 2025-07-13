# ArgoCD CLI Setup Instructions

## Prerequisites

- ArgoCD deployed in your cluster
- kubectl configured with cluster access
- ArgoCD CLI installed (`brew install argocd`)

## Setup Steps

### 1. Start Port Forward

In a separate terminal, run:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 2. Get Admin Password

```bash
# Try these in order until one works:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# OR if using Helm installation:
# kubectl -n argocd get secret argocd-secret -o jsonpath="{.data.admin\.password}" | base64 -d

# OR check Terraform output:
cd infrastructure/terraform/environments/local
terraform output -raw argocd_admin_password

# Default password might be: admin123
```

### 3. Login to ArgoCD

```bash
argocd login localhost:8080 \
  --username admin \
  --password <PASSWORD_FROM_STEP_2> \
  --insecure

argocd login localhost:8080 \
--username admin \
--password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \
--insecure

```

### 4. Verify Connection

```bash
# List applications
argocd app list

# Get specific app details
argocd app get team-namespaces
```

## Common Commands

### Check Application Status

```bash
argocd app list
argocd app get <APP_NAME>
```

### Sync Applications

```bash
# Sync single app
argocd app sync team-namespaces

# Sync all apps
argocd app sync -l argocd.argoproj.io/instance=argocd
```

### Debug Applications

```bash
# Show app details
argocd app get <APP_NAME> --refresh

# Show resources
argocd app resources <APP_NAME>

# Show logs
argocd app logs <APP_NAME>
```

## Troubleshooting

### "Argo CD server address unspecified"

- Ensure you've run `argocd login` first
- Check if port-forward is still running

### "Connection refused"

- Verify port-forward is active: `ps aux | grep port-forward`
- Restart port-forward if needed

### "Invalid username or password"

- Double-check password retrieval steps
- Try all password methods listed above
