# Example: Adding Data Platform Application

This document shows you exactly how to add a `data-platform` application using the simplified process.

## 🚀 Using the Automated Script

```bash
# Create the data-platform app
./scripts/new-app.sh data-platform api

# This creates:
# - src/data-platform/ (with FastAPI code)  
# - infrastructure/kubernetes/base/apps/data-platform.yaml (K8s manifests)
# - Updates kustomization.yaml automatically
```

## 📝 Manual Steps (if you prefer)

### 1. Create Application Code

```bash
mkdir -p src/data-platform
cd src/data-platform
```

**Dockerfile:**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["python", "main.py"]
```

**requirements.txt:**

```
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.0
sqlalchemy==2.0.23
pandas==2.1.3
```

**main.py:**

```python
from fastapi import FastAPI
from pydantic import BaseModel
import pandas as pd
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Data Platform",
    description="Data processing and analytics service",
    version="1.0.0"
)

class DataStats(BaseModel):
    total_records: int
    tables: list[str]

@app.get("/")
async def root():
    return {"message": "Data Platform API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "data-platform"}

@app.get("/ready")
async def readiness_check():
    return {"status": "ready"}

@app.get("/data/stats", response_model=DataStats)
async def get_data_stats():
    # Mock data statistics
    return DataStats(
        total_records=1000000,
        tables=["users", "transactions", "products"]
    )

@app.post("/data/process")
async def process_data():
    logger.info("Starting data processing...")
    # Add your data processing logic here
    return {"status": "processing_started", "job_id": "12345"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
```

### 2. Create Kubernetes Manifests

**infrastructure/kubernetes/base/apps/data-platform.yaml:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: data-platform
  labels:
    app.kubernetes.io/name: data-platform
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ml-platform
spec:
  ports:
    - port: 80
      targetPort: 8000
      protocol: TCP
  selector:
    app.kubernetes.io/name: data-platform
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-platform
  labels:
    app.kubernetes.io/name: data-platform
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ml-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: data-platform
  template:
    metadata:
      labels:
        app.kubernetes.io/name: data-platform
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: ml-platform
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: data-platform
        image: data-platform:latest
        ports:
        - containerPort: 8000
        env:
        - name: PORT
          value: "8000"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database-url
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

### 3. Update Kustomization

Add to `infrastructure/kubernetes/base/apps/kustomization.yaml`:

```yaml
resources:
- backend.yaml
- frontend.yaml
- data-platform.yaml  # <- Add this line
```

### 4. Deploy

```bash
# Commit and push
git add .
git commit -m "Add data-platform application"
git push

# ArgoCD will automatically deploy
# Monitor deployment
kubectl get pods -l app.kubernetes.io/name=data-platform -n ml-platform

# Access the API
kubectl port-forward svc/data-platform 8080:80 -n ml-platform
curl http://localhost:8080/health
```

## 🔍 Testing Your Application

```bash
# Build and test locally
cd src/data-platform
docker build -t data-platform .
docker run -p 8000:8000 data-platform

# Test endpoints
curl http://localhost:8000/
curl http://localhost:8000/health
curl http://localhost:8000/data/stats
```

## 🌍 Environment-Specific Configuration

If you need different configurations per environment, create overlays:

**infrastructure/kubernetes/overlays/local/data-platform-patch.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-platform
spec:
  template:
    spec:
      containers:
      - name: data-platform
        image: data-platform:dev
        env:
        - name: DEBUG
          value: "true"
        - name: LOG_LEVEL
          value: "DEBUG"
```

Add to `infrastructure/kubernetes/overlays/local/kustomization.yaml`:

```yaml
patchesStrategicMerge:
- data-platform-patch.yaml
```

## 📊 Monitoring Integration

Your app automatically gets:

- **Prometheus metrics** (via service discovery)
- **Grafana dashboards** (standard app metrics)
- **Jaeger tracing** (if you add tracing instrumentation)
- **Logs aggregation** (via Kubernetes logging)

## 🎯 Result

After deployment, you'll have:

- **API accessible at:** `http://data-platform.ml-platform/` (internal) or via port-forward
- **Health checks** working automatically
- **ArgoCD monitoring** the deployment
- **Kubernetes resources** properly labeled and organized
- **Security** policies applied (non-root, read-only filesystem, etc.)

## 📈 Scaling Up

To add more features:

1. **Database jobs:** Use `./scripts/new-app.sh data-processor job`
2. **Frontend:** Use `./scripts/new-app.sh data-dashboard frontend`
3. **Background workers:** Add more containers to your deployment
4. **Separate lifecycle:** Create ArgoCD application for independent deployment

---

This example shows how adding a new application went from a complex 10+ step process to just 4 simple steps!
