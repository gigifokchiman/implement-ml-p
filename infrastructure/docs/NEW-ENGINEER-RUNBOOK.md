# New Engineer Runbook

**Complete hands-on guide for new engineers to experience the full ML platform infrastructure.**

## 🎯 Overview

This runbook guides you through every aspect of the ML platform infrastructure, from setup to deployment to troubleshooting. By the end, you'll have:

- ✅ **Deployed** the complete infrastructure locally and to AWS
- ✅ **Experienced** all major components and workflows
- ✅ **Tested** the entire system end-to-end
- ✅ **Learned** operational procedures and troubleshooting
- ✅ **Prepared** for application development

**Estimated Time:** 4-6 hours (spread over 1-2 days)

### System Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 20GB free space
- **OS**: macOS (currently tested in macOS)

## 📋 Prerequisites

**Choose Your Approach:**


### Option A: Local Tool Installation

### Required Tools

| Tool       | Version  | Purpose                   | Installation                                                                                            |
|------------|----------|---------------------------|---------------------------------------------------------------------------------------------------------|
| Docker     | 20.10+   | Container runtime         | [Docker Desktop](https://www.docker.com/products/docker-desktop)                                        |
| Kubernetes | 1.27+    | Container orchestration   | Included with Docker Desktop                                                                            |
| Kind       | 0.20+    | Local Kubernetes clusters | `brew install kind` or [Kind Releases](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)    |
| Terraform  | 1.0+     | Infrastructure as Code    | `brew install terraform` or [Terraform Downloads](https://www.terraform.io/downloads)                   |
| kubectl    | 1.27+    | Kubernetes CLI            | `brew install kubectl` or [kubectl Install](https://kubernetes.io/docs/tasks/tools/)                    |
| Kustomize  | 5.0+     | Kubernetes configuration  | `brew install kustomize` or [Kustomize Install](https://kubectl.docs\rnetes.io/installation/kustomize/) |
| Helm       | v3.18.3+ | Deploy to k8s             | `brew install helm`                                                                                     |


### Optional Tools

| Tool | Purpose                                                | Installation     |
|------|--------------------------------------------------------|------------------|
| jq   | JSON processing                                        | `brew install jq` |
| yq   | YAML processing                                        | `brew install yq` |
| gh   | GitHub CLI                                             | `brew install gh` |
| Go   | For changing the configuration from the kind terraform | `brew install go` |

```bash
# Install required tools
brew install kind terraform kubectl kustomiz helm
# or use package manager of choice

# Verify installations
terraform --version  # >= 1.0
kubectl version --client  # >= 1.25
docker --version
kind --version
helm version
```

### Option B: Docker-Only Approach (Recommended for Quick Start)

```bash
# Only Docker is required - all other tools are in the container
brew install docker
# or use package manager of choice

# Verify Docker installation
docker --version
docker info
```

**Note:** The Docker approach uses the pre-built container at `infrastructure/Dockerfile` with all tools included.

### AWS Setup (for cloud environments)

**Local AWS CLI Installation:**
```bash
# Install AWS CLI locally
brew install awscli

# Configure AWS credentials
aws configure
# Enter your access key, secret key, region (us-west-2), output format (json)

# Verify access
aws sts get-caller-identity
```

**Docker Approach (AWS CLI included in container):**
```bash
# Configure AWS credentials in your home directory
aws configure  # If you have AWS CLI locally, or manually create files:

# Create AWS credentials directory
mkdir -p ~/.aws

# Create credentials file
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
EOF

# Create config file  
cat > ~/.aws/config << EOF
[default]
region = us-west-2
output = json
EOF

# The Docker container will mount ~/.aws and use these credentials
```

### Repository Setup

```bash
# Clone the repository
git clone https://github.com/gigifokchiman/implement-ml-p.git
cd implement-ml-p

# git submodule update --init --recursive

# Verify structure
ls -la infrastructure/
```

## 🚀 Phase 1: Local Infrastructure Experience (85 minutes)

### Step 1.1: Documentation Review (10 minutes)

```bash
# Read the main docs
cat infrastructure/README.md
cat infrastructure/docs/_CATALOG.md
```

### Step 1.2: Local Infrastructure Deployment (20 minutes)

**Option A: Automated Deployment (Recommended)**

```bash
# Use the comprehensive deployment script that handles all common issues
cd infrastructure
./scripts/deploy-local.sh

# If you need to clean up existing resources first (e.g., to fix "standard" storage class conflicts):
./scripts/deploy-local.sh --clean-first

kubectl get pods --all-namespaces

```

**Option B: Using Docker Container (No Local Tool Installation Required)**

If you prefer not to install tools locally, use the provided Docker container:

```bash
# Build the infrastructure tools container
cd infrastructure
docker build -t ml-platform-tools .

# Verify all tools are working
docker run --rm ml-platform-tools health-check.sh

# IMPORTANT: Use --network host so container can access Kind cluster
docker run -it --rm --user root \
  --network host \
  -v ~/.docker/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -v ~/.aws:/workspace/.aws:ro \
  ml-platform-tools

# Inside container - use the comprehensive deployment script
./scripts/deploy-local.sh --clean-first

kubectl get pods --all-namespaces

# Exit container when done
exit
```

**🔍 Docker Container Notes:**
- `--network host` is REQUIRED for kubectl to access the Kind cluster
- Without it, you'll get "connection refused" errors
- All infrastructure tools are pre-installed in the container

**🐳 Docker Container Benefits:**
- ✅ **No local tool installation** required
- ✅ **Consistent tool versions** across team members
- ✅ **All security scanners** pre-installed (Checkov, tfsec, Terrascan, OPA)
- ✅ **Performance tools** included (K6, Chaos Toolkit)
- ✅ **Kubernetes utilities** (k9s, kubectx, kubens, Kustomize)
- ✅ **Monitoring tools** (Prometheus CLI tools)

**📦 Container Includes:**
- Terraform, kubectl, Helm, Kind
- AWS CLI, Docker CLI latest stable
- Security: Checkov, tfsec, Terrascan, OPA, Conftest
- Monitoring: Prometheus tools, K6 load testing
- Plus helpful aliases: `k=kubectl`, `tf=terraform`, `h=helm`

### Step 1.3: ArgoCD GitOps Setup (20 minutes)

```bash
# Bootstrap ArgoCD for GitOps workflow
cd infrastructure
./scripts/bootstrap-argocd.sh local

# Check ArgoCD is running
kubectl get pods -n argocd

# Get ArgoCD dashboard access
./scripts/argocd-manage.sh dashboard

# Get admin password for login
./scripts/argocd-manage.sh password


# Apply only local environment GitOps components (not all environments)
kubectl apply -f infrastructure/kubernetes/base/gitops/argocd-projects.yaml
kubectl apply -f infrastructure/kubernetes/base/gitops/applications/ml-platform-local.yaml

# Optionally apply infrastructure monitoring for local
kubectl apply -f infrastructure/kubernetes/base/gitops/applications/monitoring.yaml

# Check what applications were created
kubectl get applications -n argocd
kubectl get appprojects -n argocd

# Sync the local application
./scripts/argocd-manage.sh refresh ml-platform-local

./scripts/argocd-manage.sh sync ml-platform-local

# Check application status
./scripts/argocd-manage.sh status ml-platform-local

kubectl patch application data-platform-local -n argocd --type=merge

# Wait for pods to start
kubectl get pods -n ml-platform --watch
# Press Ctrl+C when all pods are Running

# Check all resources deployed via ArgoCD
kubectl get all -n ml-platform
kubectl get pvc -n ml-platform
kubectl get ingress -n ml-platform
```

**🎯 ArgoCD Benefits:**
- ✅ **Visual dashboard** with real-time status
- ✅ **GitOps workflow** - sync from Git automatically
- ✅ **Diff previews** before applying changes
- ✅ **Easy rollbacks** to any previous version
- ✅ **Centralized management** across all environments

**💡 Note:** We apply individual applications rather than using `kubectl apply -k infrastructure/kubernetes/overlays/local/gitops` to avoid deploying ApplicationSets that would create applications for ALL environments (dev, staging, prod). For local development, we only want the local application.

### Step 1.4: ArgoCD Web UI Experience (10 minutes)

```bash
# Access ArgoCD dashboard (credentials from previous step)
./scripts/argocd-manage.sh dashboard

# Login with:
# Username: admin
# Password: (from ../scripts/argocd-manage.sh password)

# In the ArgoCD UI, explore:
# 1. Application overview - see ml-platform-local application
# 2. Click on ml-platform-local to see resource tree
# 3. Click "Manifest" tab to view rendered YAML
# 4. Click "Events" tab to see deployment timeline
# 5. Try "App Diff" to see any configuration changes

# CLI commands to explore
./scripts/argocd-manage.sh manifests ml-platform-local  # View rendered YAML
./scripts/argocd-manage.sh diff ml-platform-local       # Show any diffs
./scripts/argocd-manage.sh history ml-platform-local    # View revision history
```

### Step 1.5: Service Access & Testing (15 minutes)

```bash
# Port forward to access services
kubectl port-forward svc/postgresql 5432:5432 -n ml-platform &
kubectl port-forward svc/redis 6379:6379 -n ml-platform &
kubectl port-forward svc/minio 9000:9000 -n ml-platform &

# Access ArgoCD dashboard
kubectl port-forward svc/argocd-server 8080:443 -n argocd &
echo "ArgoCD available at: https://localhost:8080" 

# Test database connection
psql postgresql://admin:password@localhost:5432/metadata -c "SELECT version();"

# Test Redis connection
redis-cli -h localhost -p 6379 ping

# Test MinIO (open browser)
echo "Open http://localhost:9000 in browser"
echo "Login: minioadmin / minioadmin"

# Clean up port forwards
pkill -f "kubectl port-forward"
```

### Step 1.6: GitOps Workflow Demo (10 minutes)

```bash
# Demonstrate GitOps workflow by making a change
cd infrastructure/kubernetes/overlays/local

# Make a small change (e.g., add a label)
echo "  labels:" >> kustomization.yaml
echo "    demo: gitops-workflow" >> kustomization.yaml

# Commit and push (in real workflow)
# git add . && git commit -m "Demo GitOps workflow" && git push

# Manually trigger sync to see the change
../scripts/argocd-manage.sh refresh ml-platform-local
../scripts/argocd-manage.sh sync ml-platform-local

# View the diff that was applied
../scripts/argocd-manage.sh diff ml-platform-local

# Revert the change
git checkout -- kustomization.yaml
../scripts/argocd-manage.sh sync ml-platform-local
```

## 🧪 Phase 2: Testing & Validation Experience (45 minutes)

### Step 2.1: Run Test Suite (20 minutes)

**Using Local Tools:**
```bash
# Navigate to test directory
cd infrastructure/terraform

# Run formatting tests
./tests/run-tests.sh format

# Run validation tests
./tests/run-tests.sh validate

# Run unit tests
./tests/run-tests.sh unit

# Run all tests
./tests/run-tests.sh
```

**Using Docker Container:**
```bash
# Run tests using the infrastructure tools container
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.aws:/workspace/.aws:ro \
  ml-platform-tools \
  bash -c "cd terraform && ./tests/run-tests.sh"

# Or run specific tests
docker run -it --rm \
  -v $(pwd):/workspace \
  ml-platform-tools \
  bash -c "cd terraform && ./tests/run-tests.sh validate"
```

### Step 2.2: Security Testing (10 minutes)

```bash
# Run security scans
cd tests/security
./scan-local.sh

# Check compliance
cd ../terraform/compliance
checkov -f checkov-local.yaml
```

### Step 2.3: Performance Testing (15 minutes)

```bash
# Run basic load tests
cd infrastructure/tests/performance/k6
k6 run basic-load-test.js

# Check resource usage
kubectl top nodes
kubectl top pods -n ml-platform

# View metrics
kubectl get --raw /metrics | grep -i ml_platform
```

## ☁️ Phase 3: AWS Environment Experience (90 minutes)

### Step 3.1: Development Environment (45 minutes)

```bash
# Navigate to dev environment
cd infrastructure/terraform/environments/dev

# Review configuration
cat terraform.tfvars
cat main.tf

# Initialize and plan
terraform init
terraform plan

# Apply infrastructure (will create AWS resources)
terraform apply
# Type 'yes' when prompted

# Update kubeconfig for EKS
aws eks update-kubeconfig --region us-west-2 --name ml-platform-dev

# Verify EKS cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Deploy applications
cd ../../kubernetes
kubectl apply -k overlays/dev

# Check deployment
kubectl get pods -n ml-platform --watch
```

### Step 3.2: Monitoring & Observability (25 minutes)

```bash
# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/ml-platform"

# View EKS cluster in AWS Console
echo "https://console.aws.amazon.com/eks/home?region=us-west-2#/clusters"

# Check RDS database
aws rds describe-db-instances --query 'DBInstances[?DBName==`metadata`]'

# Check ElastiCache
aws elasticache describe-cache-clusters

# Port forward to access Grafana (if deployed)
kubectl port-forward svc/grafana 3000:3000 -n monitoring &
echo "Open http://localhost:3000 (admin/admin)"
```

### Step 3.3: Production Environment (20 minutes)

```bash
# Navigate to prod environment
cd infrastructure/terraform/environments/prod

# Review production configuration
cat terraform.tfvars
diff ../dev/terraform.tfvars terraform.tfvars

# Plan production deployment (DO NOT APPLY in real environment)
terraform init
terraform plan

# For learning: show what would be created
echo "Production would create:"
echo "- Multi-AZ EKS cluster"
echo "- Production RDS with backups"
echo "- ElastiCache cluster"
echo "- S3 buckets with versioning"
echo "- Complete monitoring stack"
```

## 🛠️ Phase 4: Operations Experience (60 minutes)

### Step 4.1: Configuration Management (20 minutes)

```bash
# Explore Kustomize structure
cd infrastructure/kubernetes
tree base/
tree overlays/

# See how overlays work
kustomize build overlays/local
kustomize build overlays/dev
kustomize build overlays/prod

# Compare environments
diff <(kustomize build overlays/local) <(kustomize build overlays/dev)
```

### Step 4.2: ArgoCD Troubleshooting Practice (25 minutes)

```bash
# Simulate ArgoCD troubleshooting scenarios

# 1. Check application health
../scripts/argocd-manage.sh status ml-platform-local

# 2. Simulate application issues by making invalid YAML
cd infrastructure/kubernetes/overlays/local
echo "invalid: yaml: syntax" >> kustomization.yaml

# 3. Refresh ArgoCD to detect the issue
../scripts/argocd-manage.sh refresh ml-platform-local

# 4. Check sync status (should show error)
../scripts/argocd-manage.sh status ml-platform-local

# 5. Debug the application
../scripts/argocd-manage.sh debug ml-platform-local

# 6. View ArgoCD events
../scripts/argocd-manage.sh events ml-platform-local

# 7. Fix the issue
git checkout -- kustomization.yaml

# 8. Sync and verify fix
../scripts/argocd-manage.sh sync ml-platform-local
../scripts/argocd-manage.sh status ml-platform-local

# 9. Demonstrate rollback capability
../scripts/argocd-manage.sh history ml-platform-local
# Note a good revision number and practice rollback
../scripts/argocd-manage.sh rollback ml-platform-local <revision-number>





```


### Step 4.3: Backup & Recovery (15 minutes)

```bash
# Create backup of important data
kubectl get configmaps -n ml-platform -o yaml > configmaps-backup.yaml
kubectl get secrets -n ml-platform -o yaml > secrets-backup.yaml

# Simulate data loss
kubectl delete configmap app-config -n ml-platform

# Restore from backup
kubectl apply -f configmaps-backup.yaml

# Verify restoration
kubectl get configmap app-config -n ml-platform
```

## 📱 Phase 5: Application Development Preparation (45 minutes)

> **⚡ Quick App Addition**: For adding new applications, see [ADD-NEW-APPLICATION.md](./ADD-NEW-APPLICATION.md) for a
> simplified 4-step process, or use the automated script: `../scripts/new-app.sh <app-name> [type]`

### Step 5.1: Quick Application Addition Demo (10 minutes)

```bash
# Demonstrate the simplified app addition process
cd infrastructure

# Create a sample application using the automated script
../scripts/new-app.sh sample-app api

# This creates:
# - src/sample-app/ (with FastAPI code and Dockerfile)
# - infrastructure/kubernetes/base/apps/sample-app.yaml (K8s manifests)
# - Updates kustomization.yaml automatically

# Deploy the new app via GitOps
git add .
git commit -m "Add sample-app for demo"
# git push  # (Uncomment to actually deploy)

# Check the generated files
ls -la src/sample-app/
cat infrastructure/kubernetes/base/apps/sample-app.yaml

# Clean up demo files
git reset --hard HEAD~1
rm -rf src/sample-app
git checkout -- infrastructure/kubernetes/base/apps/kustomization.yaml
```

### Step 5.2: Development Environment Setup (20 minutes)

```bash
# Create application directory structure
mkdir -p app/{backend,frontend,ml-jobs,shared}

# Set up Python environment for backend
cd app/backend
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install fastapi uvicorn sqlalchemy psycopg2-binary redis

# Create basic FastAPI app
cat > main.py << 'EOF'
from fastapi import FastAPI
import redis
import psycopg2

app = FastAPI(title="ML Platform API")

@app.get("/")
def read_root():
    return {"message": "ML Platform API is running!"}

@app.get("/health")
def health_check():
    # Test database connection
    try:
        conn = psycopg2.connect("postgresql://admin:password@localhost:5432/metadata")
        conn.close()
        db_status = "connected"
    except:
        db_status = "disconnected"
    
    # Test Redis connection
    try:
        r = redis.Redis(host='localhost', port=6379)
        r.ping()
        redis_status = "connected"
    except:
        redis_status = "disconnected"
    
    return {
        "status": "healthy",
        "database": db_status,
        "cache": redis_status
    }
EOF

# Test the API locally
uvicorn main:app --reload --port 8000 &

# Test endpoints
curl http://localhost:8000/
curl http://localhost:8000/health

# Stop the API
pkill -f uvicorn
```

### Step 5.2: Frontend Setup (15 minutes)

```bash
# Set up React frontend
cd ../frontend
npx create-react-app ml-platform-ui
cd ml-platform-ui

# Create basic dashboard
cat > src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [apiStatus, setApiStatus] = useState(null);

  useEffect(() => {
    fetch('http://localhost:8000/health')
      .then(res => res.json())
      .then(data => setApiStatus(data))
      .catch(err => console.error(err));
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>ML Platform Dashboard</h1>
        {apiStatus && (
          <div>
            <p>API Status: {apiStatus.status}</p>
            <p>Database: {apiStatus.database}</p>
            <p>Cache: {apiStatus.cache}</p>
          </div>
        )}
      </header>
    </div>
  );
}

export default App;
EOF

# Start frontend (in background)
npm start &
echo "Frontend running at http://localhost:3000"
```

### Step 5.3: ML Job Example (10 minutes)

```bash
# Create sample ML training job
cd ../../ml-jobs
mkdir training
cd training

cat > train_model.py << 'EOF'
#!/usr/bin/env python3
"""Sample ML training job for the platform."""

import os
import pickle
import numpy as np
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

def train_model():
    print("Starting model training...")
    
    # Generate sample data
    X, y = make_classification(n_samples=1000, n_features=20, n_classes=2, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train model
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate
    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    print(f"Model accuracy: {accuracy:.4f}")
    
    # Save model
    os.makedirs('models', exist_ok=True)
    with open('models/model.pkl', 'wb') as f:
        pickle.dump(model, f)
    
    print("Model saved to models/model.pkl")
    return accuracy

if __name__ == "__main__":
    accuracy = train_model()
    print(f"Training completed with accuracy: {accuracy:.4f}")
EOF

# Run the training job
python train_model.py
```

## 📊 Phase 6: Monitoring & Metrics (30 minutes)

### Step 6.1: Infrastructure Metrics (15 minutes)

```bash
# Check cluster metrics
kubectl top nodes
kubectl top pods -n ml-platform

# Get detailed node information
kubectl describe nodes

# Check resource usage
kubectl get pods -n ml-platform -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory

# View cluster events
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp
```

### Step 6.2: Application Metrics (15 minutes)

```bash
# Check application logs
kubectl logs -l app=backend -n ml-platform --tail=50

# Follow logs in real-time
kubectl logs -l app=backend -n ml-platform -f &

# Generate some activity
curl http://localhost:8000/health
curl http://localhost:8000/

# Check custom metrics (if configured)
kubectl get --raw /metrics | grep -E "(ml_|http_)"

# Stop log following
pkill -f "kubectl logs"
```

## 🧹 Phase 7: Cleanup & Documentation (30 minutes)

### Step 7.1: Environment Cleanup (15 minutes)

```bash
# Stop local applications
pkill -f "npm start"
pkill -f "uvicorn"

# Clean up Kubernetes resources
kubectl delete namespace ml-platform

# Clean up docker
docker system prune -af

# Clean up AWS dev environment (optional - costs money)
cd infrastructure/terraform/environments/local
terraform destroy
# Type 'yes' when prompted

cd ../dev
terraform destroy

# Clean up terraform state
rm -rf infrastructure/terraform/environments/local/.terraform*
rm -rf infrastructure/terraform/environments/local/terraform.tfstate*

```

### Step 7.2: Learning Documentation (15 minutes)

```bash
# Create your learning notes
cat > infrastructure/docs/MY-LEARNING-NOTES.md << 'EOF'
# My Infrastructure Learning Notes

## What I Learned Today

### Infrastructure Components
- [ ] Terraform for infrastructure provisioning
- [ ] Kind for local Kubernetes development
- [ ] Kustomize for environment-specific configurations
- [ ] AWS EKS for production Kubernetes

### Key Concepts
- [ ] Two-layer architecture (Infrastructure + Applications)
- [ ] Environment parity (local mirrors production)
- [ ] GitOps workflows
- [ ] Infrastructure as Code

### Operational Procedures
- [ ] Deployment workflows
- [ ] Testing strategies
- [ ] Monitoring and troubleshooting
- [ ] Security scanning

### Next Steps for Application Development
- [ ] Choose ML framework (PyTorch/TensorFlow/Scikit-learn)
- [ ] Set up development workflow
- [ ] Implement ML training pipelines
- [ ] Build web dashboard

## Questions for Team
1. Which ML frameworks are we prioritizing?
2. What's our data pipeline strategy?
3. How do we handle model versioning?
4. What monitoring tools should we implement?

## Improvements Ideas
1. Add automated testing for applications
2. Implement proper secret management
3. Set up continuous deployment
4. Add performance monitoring

EOF

# Review what you've accomplished
echo "🎉 Congratulations! You've completed the full infrastructure experience!"
echo ""
echo "You have successfully:"
echo "✅ Deployed infrastructure locally and to AWS"
echo "✅ Set up ArgoCD GitOps workflow"
echo "✅ Experienced visual deployment management"
echo "✅ Tested all major components"
echo "✅ Learned operational procedures"
echo "✅ Set up development environment"
echo "✅ Prepared for application development"
echo ""
echo "Next steps:"
echo "📚 Review APPLICATION-TRANSITION.md for app development"
echo "🚀 Start building your first ML application"
echo "👥 Share your learning notes with the team"
```

## 🚨 Common Issues & Solutions

### Terraform Kind Provider Checksum Error

If you encounter this error:
```
Error: Failed to install provider
Error while installing gigifokchiman/kind v0.1.0: the local package doesn't match checksums
```

**Root Cause**: The custom terraform-provider-kind has platform-specific checksums that don't match across different architectures (ARM64 vs AMD64).

**Solution**:
```bash
# Navigate to the local environment
cd infrastructure/terraform/environments/local

# Remove the lock file and terraform cache
rm -f .terraform.lock.hcl
rm -rf .terraform

# Reinitialize Terraform (this will generate new checksums for your platform)
terraform init --upgrade

# If you still get errors, try building the provider:
cd ../../terraform-provider-kind
go mod tidy
go build -o terraform-provider-kind

# Copy to the correct plugin directory
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/$(go env GOOS)_$(go env GOARCH)
cp terraform-provider-kind ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/$(go env GOOS)_$(go env GOARCH)/

# Go back and try again
cd ../../environments/local
terraform init
```

**Prevention**: This error typically occurs when:
- Switching between different machines/architectures
- Multiple team members with different platforms
- The lock file was committed from a different platform

**Quick Fix** (if above doesn't work):
```bash
# Use the comprehensive deployment script - handles everything automatically
cd infrastructure
./scripts/deploy-local.sh --clean-first
```

**Emergency Reset** (nuclear option):
```bash
# Complete clean slate
cd infrastructure/terraform/environments/local
rm -rf .terraform*
rm -f terraform.tfstate*
terraform init
terraform apply -target=kind_cluster.default
# Then continue with normal terraform apply
```

### PVC Timeout Issues

If Persistent Volume Claims (PVCs) are stuck in "Pending" status:

**Root Cause**: Kind uses "WaitForFirstConsumer" volume binding mode - PVCs only bind when a pod tries to use them.

**Solution**:
```bash
# Check PVC status
kubectl get pvc --all-namespaces

# If PVCs are pending, create temporary pods to bind them
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pvc-binder-temp
  namespace: database
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "10"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: postgres-pvc
  restartPolicy: Never
EOF

# Wait for binding, then delete temp pod
kubectl wait --for=condition=Ready pod/pvc-binder-temp -n database --timeout=60s
kubectl delete pod pvc-binder-temp -n database

# Repeat for other stuck PVCs (redis-pvc, minio-pvc, etc.)
```

### Terraform State Lock Issues

If you see "state lock" errors:

```bash
cd infrastructure/terraform/environments/local
rm -f .terraform.tfstate.lock.info
terraform apply
```

### Docker Container Can't Access Kind Cluster

If you see connection refused errors when using kubectl from inside the Docker container:

```
Error: couldn't get current server API group list: Get "https://127.0.0.1:58463/api": dial tcp 127.0.0.1:58463: connect: connection refused
```

**Root Cause**: Kind cluster runs on the Docker Desktop host, but the container tries to connect to localhost inside the container.

**Solution 1 - Use Host Network** (Recommended):
```bash
# Run container with host networking
docker run -it --rm --user root \
  --network host \
  -v ~/.docker/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -v ~/.aws:/workspace/.aws:ro \
  ml-platform-tools

# Inside container, kubectl should now work
kubectl cluster-info
```

**Solution 2 - Access from Host**:
```bash
# Run Terraform inside container, but kubectl from host
# Inside container:
cd terraform/environments/local
terraform apply
exit

# On host:
kubectl config use-context kind-ml-platform-local
kubectl get pods --all-namespaces
```

**Solution 3 - Fix kubeconfig**:
```bash
# Inside container, get the complete kubeconfig from Kind (includes certificates)
kind get kubeconfig --name ml-platform-local > ~/.kube/config

# Test kubectl
kubectl cluster-info
kubectl get pods --all-namespaces
```

### ArgoCD Application Stuck During Deletion

If ArgoCD applications get stuck during deletion with finalizers:

```bash
# Force delete by removing finalizers
kubectl patch application -n argocd <app-name> -p '{"metadata":{"finalizers":[]}}' --type=merge

# Or force delete with grace period
kubectl delete application -n argocd <app-name> --force --grace-period=0

# Apply GitOps config with force to overwrite conflicts
kubectl apply -k infrastructure/kubernetes/overlays/local/gitops --force
```

### ArgoCD CLI "Server Address Unspecified" Error

If ArgoCD CLI commands fail with "server address unspecified":

```bash
# Use kubectl-based operations instead of argocd CLI
kubectl patch application -n argocd <app-name> --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}'

# For refresh, use annotation update
kubectl patch application -n argocd <app-name> --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"'$(date +%s)'"}}}'
```

### ArgoCD CRD Missing Error

If you get "no matches for kind 'ArgoCD' in version 'argoproj.io/v1beta1'" error:

```bash
# Install ArgoCD CRDs first
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Then apply GitOps configuration
kubectl apply -k infrastructure/kubernetes/overlays/local/gitops

# Alternative: Apply components individually
kubectl apply -f infrastructure/kubernetes/base/gitops/argocd-projects.yaml
kubectl apply -f infrastructure/kubernetes/base/gitops/applications/ml-platform-local.yaml
```

**Root Cause**: The bootstrap script installs core ArgoCD but not the operator CRDs that some GitOps configurations expect.

### ApplicationSet Template Expression Errors

If ApplicationSet fails with "must be of type integer/boolean" errors:

```bash
# Check the ApplicationSet for template expressions in wrong fields
kubectl get applicationset -n argocd -o yaml

# Edit to use static values instead of templates for type-sensitive fields
# Example: Change prune: '{{expression}}' to prune: true
```

## 🆘 Getting Help

If you encounter issues during this runbook:

1. **Check Documentation**: All answers are in [docs/README.md](./README.md)
2. **Review Troubleshooting**: See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
3. **Run Tests**: Use `./tests/run-tests.sh` to validate your environment
4. **Ask Team**: Share your MY-LEARNING-NOTES.md with questions

## 🚀 What's Next?

You're now ready to start application development! Follow the [APPLICATION-TRANSITION.md](./APPLICATION-TRANSITION.md) guide to begin building ML applications on this solid infrastructure foundation.

---

*Welcome to the team! You now understand our entire infrastructure stack.*


## Appendix

### Environment Variables

```bash
# Core settings
export KUBECONFIG=$HOME/.kube/config
export KUBE_CONTEXT=kind-ml-platform-local

# Development settings
export REGISTRY_URL=localhost:5001
export ENVIRONMENT=local

# AWS settings (for cloud deployments)
export AWS_PROFILE=ml-platform-dev
export AWS_REGION=us-east-1
```

### Useful Aliases

Add to your shell profile:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kml='kubectl -n ml-platform'
alias kctx='kubectl config use-context'

# Project aliases
alias mlp='cd ~/path/to/ml-platform'
alias mlpi='cd ~/path/to/ml-platform/infrastructure'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
```





