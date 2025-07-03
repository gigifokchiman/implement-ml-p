# Adding New Applications Guide

**Quick guide for adding new applications to the ML Platform**

## 🚀 Quick Start (Simple Apps)

For most applications, you only need to follow these 4 steps:

### 1. Create Your Application

```bash
# Create application directory
mkdir -p src/your-app-name
cd src/your-app-name

# Create basic files
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "main.py"]
EOF

cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
EOF

cat > main.py << 'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World", "app": "your-app-name"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
```

### 2. Create Kubernetes Manifests

```bash
# Create the manifest file
cat > infrastructure/kubernetes/base/apps/your-app-name.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: your-app-name
  labels:
    app.kubernetes.io/name: your-app-name
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ml-platform
spec:
  ports:
    - port: 80
      targetPort: 8000
      protocol: TCP
  selector:
    app.kubernetes.io/name: your-app-name
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app-name
  labels:
    app.kubernetes.io/name: your-app-name
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ml-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: your-app-name
  template:
    metadata:
      labels:
        app.kubernetes.io/name: your-app-name
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: ml-platform
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: your-app-name
        image: your-app-name:latest
        ports:
        - containerPort: 8000
        env:
        - name: PORT
          value: "8000"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
EOF
```

### 3. Update Kustomization

```bash
# Add your app to the kustomization file
cat >> infrastructure/kubernetes/base/apps/kustomization.yaml << 'EOF'
- your-app-name.yaml
EOF
```

### 4. Deploy

```bash
# Deploy via ArgoCD (GitOps)
git add .
git commit -m "Add your-app-name application"
git push

# ArgoCD will automatically deploy your app
# Or manually sync: kubectl patch application ml-platform-local -n argocd --type='merge' -p='{"operation":{"sync":{}}}'
```

## 🎯 That's It!

Your application will be deployed automatically by ArgoCD. Access it via:

```bash
kubectl port-forward svc/your-app-name 8080:80 -n ml-platform
# Then visit: http://localhost:8080
```

---

## 🔧 Advanced Scenarios

### Complex Applications (Separate Lifecycle)

For applications that need independent deployment cycles:

#### 1. Create ArgoCD Application

```yaml
# infrastructure/kubernetes/base/gitops/applications/your-app-name.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: your-app-name-local
  namespace: argocd
spec:
  project: ml-platform
  source:
    repoURL: https://github.com/gigifokchiman/implement-ml-p
    targetRevision: HEAD
    path: app/your-app-name/kustomize/overlays/local
  destination:
    server: https://kubernetes.default.svc
    namespace: ml-platform
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

#### 2. Create Self-Contained Structure

```bash
mkdir -p app/your-app-name/kustomize/{base,overlays/{local,dev,staging,prod}}

# Base kustomization
cat > app/your-app-name/kustomize/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app.kubernetes.io/name: your-app-name
  app.kubernetes.io/part-of: ml-platform
EOF

# Environment overlay
cat > app/your-app-name/kustomize/overlays/local/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

images:
- name: your-app-name
  newTag: dev

patchesStrategicMerge:
- deployment-patch.yaml
EOF
```

### Database Applications

For apps that need database connections:

```yaml
# Add to your deployment manifest
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: postgres-secret
        key: database-url
  - name: REDIS_URL
    value: "redis://redis.ml-platform:6379"
```

### Background Jobs

For cron jobs or batch processing:

```yaml
# infrastructure/kubernetes/base/apps/your-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: your-job
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: your-job
              image: your-app-name:latest
              command: [ "python", "job.py" ]
```

## 📋 Application Template Generator

Use this script to quickly scaffold new applications:

```bash
# Save as: scripts/new-app.sh
#!/bin/bash
APP_NAME=$1
if [ -z "$APP_NAME" ]; then
  echo "Usage: ./new-app.sh <app-name>"
  exit 1
fi

echo "Creating new application: $APP_NAME"

# Create source directory
mkdir -p "src/$APP_NAME"
# Generate templates...
# (Copy from examples above)

echo "✅ Application $APP_NAME created!"
echo "📝 Next steps:"
echo "   1. Edit src/$APP_NAME/main.py"
echo "   2. Build your Docker image"
echo "   3. git add . && git commit -m 'Add $APP_NAME' && git push"
echo "   4. ArgoCD will deploy automatically"
```

## 🚨 Common Issues

**App not starting?**

- Check logs: `kubectl logs -l app.kubernetes.io/name=your-app-name -n ml-platform`
- Verify health check endpoints work

**ArgoCD not syncing?**

- Check ArgoCD app status: `kubectl get applications -n argocd`
- Force sync: `argocd app sync your-app-name-local`

**Port conflicts?**

- Each app needs a unique port
- Update the port mapping in your service/deployment

---

This simplified approach reduces the complexity from ~10 steps to just 4 steps for most applications, while still
supporting advanced scenarios when needed.
