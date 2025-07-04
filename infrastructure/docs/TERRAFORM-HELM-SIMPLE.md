# Simple Terraform + Helm Integration

## 🎯 **Core Concept**

- **Terraform**: Manages core infrastructure (cluster, networking, storage)
- **Helm**: Template engine for easy application deployment

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌─────────────────┐
│    Terraform    │    │      Helm       │
│                 │    │                 │
│ • Kind Cluster  │────▶ • PostgreSQL    │
│ • Networking    │    │ • Redis         │
│ • Storage Class │    │ • MinIO         │
│ • Namespace     │    │ • Application   │
│ • Base Config   │    │ • Monitoring    │
└─────────────────┘    └─────────────────┘
```

## 🚀 **Quick Usage**

Deploy a new application platform in one command:

```bash
./scripts/deploy-new-app.sh analytics-platform 8110 8463
```

This will:
1. **Terraform** creates the cluster and base infrastructure
2. **Helm** deploys PostgreSQL, Redis, MinIO, and your application

## 📁 **File Structure**

```
infrastructure/
├── terraform/environments/template/     # Terraform template
├── helm/charts/platform-template/       # Helm chart template  
├── scripts/deploy-new-app.sh           # Deployment script
└── helm/values/                        # App-specific values
```

## 🔧 **How It Works**

### **Step 1: Terraform Creates Core Infrastructure**
```hcl
# terraform/environments/template/main.tf
resource "kind_cluster" "app_cluster" {
  name = "${var.app_name}-local"
  # ... cluster configuration
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.app_name
  }
}
```

### **Step 2: Helm Deploys Applications**
```bash
helm install analytics-platform ./helm/charts/platform-template \
  --namespace analytics-platform \
  --values ./helm/values/analytics-platform-values.yaml
```

## 📋 **What You Get**

For each new application:

✅ **Terraform-managed infrastructure:**
- Kind cluster with proper networking
- Kubernetes namespace  
- Storage classes
- Base security policies

✅ **Helm-deployed applications:**
- PostgreSQL database
- Redis cache
- MinIO object storage
- Your application
- Optional monitoring

## 🎛️ **Customization**

Edit the Helm values file for each app:

```yaml
# helm/values/my-app-values.yaml
app:
  name: "my-app"
  
database:
  enabled: true
  postgresql:
    auth:
      database: "my_app_db"
      
services:
  api:
    image:
      repository: "my-company/my-app"
      tag: "v1.0.0"
```

## 🔄 **Management**

```bash
# Deploy
./scripts/deploy-new-app.sh my-app

# Upgrade application
helm upgrade my-app ./helm/charts/platform-template \
  --namespace my-app \
  --values ./helm/values/my-app-values.yaml

# Check status  
kubectl get pods -n my-app
helm status my-app -n my-app

# Cleanup
helm uninstall my-app -n my-app
cd terraform/environments/my-app && terraform destroy
kind delete cluster --name my-app-local
```

## 🎯 **Benefits**

- **Simple**: One command deployment
- **Terraform**: Handles infrastructure concerns
- **Helm**: Handles application templating and versioning
- **Isolated**: Each app gets its own cluster and resources
- **Scalable**: Easy to create new environments
- **Clean separation**: Infrastructure vs Applications

This gives you the best of both worlds: Terraform's infrastructure management + Helm's application templating! 🚀