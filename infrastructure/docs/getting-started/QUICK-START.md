# 🚀 Quick Start Guide

Get up and running with the ML Platform in 30 minutes or less.

## ⚡ Super Quick Start (Docker Compose)

For immediate local development without Kubernetes complexity:

```bash
# 1. Clone and setup
git clone https://github.com/gigifokchiman/implement-ml-p.git
cd implement-ml-p

# 2. Configure environment
cp .env.example .env
# Edit .env with your secure passwords

# 3. Start the platform
docker-compose up -d

# 4. Verify services
curl http://localhost:3000  # Frontend
curl http://localhost:8000  # Backend API
```

**You now have**: Frontend, Backend, Database, Redis, ML Service, and Monitoring running locally!

## 🏗️ Production-Ready Kubernetes (30 minutes)

For the full infrastructure experience with security and team isolation:

### Prerequisites Check

```bash
# Verify required tools
docker --version     # Docker 20.10+
kind --version       # Kind 0.20+
kubectl version      # kubectl 1.28+
terraform --version  # Terraform 1.6+
```

### One-Command Deployment

```bash
# Deploy complete infrastructure
cd infrastructure
make init-tf-local && make apply-tf-local
```

### Manual Step-by-Step

```bash
# 1. Initialize Terraform
cd infrastructure/terraform/environments/local
terraform init

# 2. Plan deployment
terraform plan

# 3. Apply infrastructure
terraform apply -auto-approve

# 4. Verify cluster
kubectl get nodes
kubectl get namespaces

# 5. Check applications
kubectl get pods -A
```

## 🔍 Verify Your Deployment

### Docker Compose Verification

```bash
# Check all services are running
docker-compose ps

# View logs
docker-compose logs backend
docker-compose logs frontend

# Test API
curl http://localhost:8000/health
```

### Kubernetes Verification

```bash
# Check cluster status
kubectl cluster-info

# Verify namespaces
kubectl get namespaces | grep app-

# Check team workloads
kubectl get pods -n app-core-team
kubectl get pods -n app-ml-team
kubectl get pods -n app-data-team

# Test services
kubectl port-forward svc/frontend 3000:80 -n app-core-team &
curl http://localhost:3000
```

## 🎯 What You Get

### Docker Compose Environment

- **Frontend**: React app at http://localhost:3000
- **Backend**: REST API at http://localhost:8000
- **Database**: PostgreSQL with persistent data
- **Cache**: Redis for session management
- **MinIO**: S3-compatible storage at http://localhost:9000
- **Monitoring**: Basic container monitoring with Prometheus

### Kubernetes Environment (Kind Cluster)

- **🏗️ Infrastructure**: Kind cluster with 3 layers (compositions→platform→providers)
- **👥 Team Isolation**: 5 namespaces (app-core-team, app-ml-team, app-data-team, security-scanning,
  data-platform-monitoring)
- **🔐 Security**: Falco DaemonSet, Trivy server, Network policies, RBAC
- **📊 Monitoring**: Prometheus Operator, Grafana, Jaeger distributed tracing
- **🚀 GitOps**: ArgoCD with automatic sync every 3 minutes
- **🔍 Security Scanning**: Continuous image scanning and runtime threat detection

## 🛠️ Common Development Tasks

### Access Applications

```bash
# Frontend (React app)
kubectl port-forward svc/frontend 3000:80 -n app-core-team &

# Backend API
kubectl port-forward svc/backend 8000:80 -n app-core-team &

# ArgoCD UI (admin/initial-password)
kubectl port-forward svc/argocd-server 8080:443 -n argocd &

# Grafana Dashboard (admin/admin)
kubectl port-forward svc/grafana 3000:80 -n data-platform-monitoring &

# Get ArgoCD initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access applications:
# - Frontend: http://localhost:3000
# - Backend: http://localhost:8000
# - ArgoCD: https://localhost:8080 (ignore TLS warning)
# - Grafana: http://localhost:3000 (if frontend not running)
```

### View Logs

```bash
# Application logs
kubectl logs -f deployment/backend -n app-core-team

# Infrastructure logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Security logs
kubectl logs -f daemonset/falco -n security-scanning
```

### Deploy New Application

```bash
# Use the 4-step application template
cd infrastructure/kubernetes/base
cp -r app-template app-myservice

# Edit manifests
vim app-myservice/deployment.yaml

# Deploy via ArgoCD
kubectl apply -f app-myservice/argocd-application.yaml
```

## 🔧 Troubleshooting

### Docker Compose Issues

```bash
# Service not starting
docker-compose logs <service-name>

# Reset everything
docker-compose down -v
docker-compose up -d

# Check port conflicts
docker-compose ps
netstat -tulpn | grep :3000
```

### Kubernetes Issues

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check specific namespace
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Reset cluster
kind delete cluster --name gigifokchiman
make apply-tf-local
```

### Common Solutions

| Issue               | Solution                                                       |
|---------------------|----------------------------------------------------------------|
| Port already in use | Change ports in docker-compose.yml or kill conflicting process |
| Terraform fails     | Run `terraform init` and check provider versions               |
| Pods pending        | Check node resources: `kubectl describe nodes`                 |
| Permission denied   | Verify RBAC: `kubectl auth can-i <verb> <resource>`            |
| Network issues      | Check network policies and firewall rules                      |

## 📚 Next Steps

### For Application Development

- **[Development Workflow](DEVELOPMENT-WORKFLOW.md)** - Day-to-day development tasks
- **[Add New Application](../ADD-NEW-APPLICATION.md)** - Deploy your first app
- **[Testing Guide](../reference/TESTING-GUIDE.md)** - Test your applications

### For Infrastructure Management

- **[Architecture Overview](../ARCHITECTURE.md)** - Understand the system design
- **[Security Guide](../SECURITY-COMPREHENSIVE-GUIDE.md)** - Security implementation
- **[Operations Manual](../operations/OPERATIONAL-RUNBOOKS.md)** - Day-to-day operations

### For Team Onboarding

- **[New Engineer Runbook](../NEW-ENGINEER-RUNBOOK.md)** - Complete onboarding guide
- **[Best Practices](../BEST-PRACTICES.md)** - Development standards
- **[Troubleshooting](../reference/TROUBLESHOOTING.md)** - Common issues and solutions

## 🎉 You're Ready!

Congratulations! You now have a production-ready ML platform running locally. The platform includes:

✅ **Security**: Network policies, RBAC, vulnerability scanning  
✅ **Monitoring**: Metrics, logs, traces, alerts  
✅ **GitOps**: Automated deployments with ArgoCD  
✅ **Team Isolation**: Multi-tenant architecture  
✅ **Developer Tools**: Local development environment

**Happy coding!** 🚀

---

*Need help? Check our [Troubleshooting Guide](../reference/TROUBLESHOOTING.md) or create an issue.*
