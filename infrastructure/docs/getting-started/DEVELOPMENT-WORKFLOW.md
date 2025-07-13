# 👨‍💻 Development Workflow Guide

A comprehensive guide to day-to-day development workflows on the ML Platform.

## 🔄 Daily Development Cycle

### 1. Start Your Development Environment

#### Option A: Docker Compose (Fastest)

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f backend
```

#### Option B: Kubernetes (Production-like)

```bash
# Ensure cluster is running
kubectl cluster-info

# Port forward services for development
kubectl port-forward svc/backend 8000:80 -n app-core-team &
kubectl port-forward svc/frontend 3000:80 -n app-core-team &
kubectl port-forward svc/postgres 5432:5432 -n app-core-team &
```

### 2. Feature Development Workflow

```mermaid
graph LR
    A[Pull Latest] --> B[Create Feature Branch]
    B --> C[Local Development]
    C --> D[Test Locally]
    D --> E[Security Scan]
    E --> F[Commit & Push]
    F --> G[Create PR]
    G --> H[CI/CD Pipeline]
    H --> I[Code Review]
    I --> J[Merge to Main]
    J --> K[Deploy to Dev]
```

#### Step-by-Step Process

```bash
# 1. Start with latest code
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/user-authentication

# 3. Make your changes
# ... edit code ...

# 4. Test locally
make test-all
npm run test:unit
npm run test:integration

# 5. Security scan
make security-scan
npm run security:audit

# 6. Commit with conventional commits
git add .
git commit -m "feat: add user authentication with JWT"

# 7. Push and create PR
git push origin feature/user-authentication
gh pr create --title "Add user authentication" --body "Implements JWT-based auth"
```

### 3. Testing Strategy

#### Local Testing

```bash
# Unit tests
npm test                          # Frontend tests
pytest tests/unit/               # Backend tests
python -m pytest tests/ml/      # ML pipeline tests

# Integration tests
docker-compose up -d
npm run test:integration
pytest tests/integration/

# End-to-end tests
npm run test:e2e
```

#### Infrastructure Testing

```bash
# Terraform validation
cd infrastructure/terraform/environments/local
terraform validate
terraform plan

# Kubernetes manifest validation
kubectl apply --dry-run=client -f infrastructure/kubernetes/

# Security testing
checkov -d infrastructure/terraform/
kubesec scan infrastructure/kubernetes/base/app-ml-platform/
```

## 🎯 Team-Specific Workflows

### Core Team (Platform/Infrastructure)

#### Infrastructure Changes

```bash
# 1. Test infrastructure changes locally
cd infrastructure/terraform/environments/local
terraform plan

# 2. Apply to local cluster
terraform apply

# 3. Validate deployment
kubectl get pods -A
kubectl get events --sort-by=.metadata.creationTimestamp

# 4. Test specific components
make test-infrastructure
make test-security
```

#### Adding New Infrastructure Components

```bash
# 1. Create new module
mkdir infrastructure/terraform/modules/platform/new-component
cd infrastructure/terraform/modules/platform/new-component

# 2. Write module files
touch main.tf variables.tf outputs.tf

# 3. Test module
terraform init
terraform validate

# 4. Add to composition
vim ../../compositions/data-platform/main.tf
```

### ML Team (Machine Learning)

#### ML Model Development

```bash
# 1. Start ML development environment
kubectl port-forward svc/jupyter 8888:8888 -n app-ml-team
kubectl port-forward svc/mlflow 5000:5000 -n app-ml-team

# 2. Develop model locally
cd src/ml/
jupyter notebook  # or use port-forwarded Jupyter

# 3. Train model
python train_model.py --config configs/experiment_1.yaml

# 4. Track experiment with MLflow
mlflow ui --host 0.0.0.0 --port 5000

# 5. Deploy model as Kubernetes job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: model-training-$(date +%s)
  namespace: app-ml-team
spec:
  template:
    spec:
      containers:
      - name: trainer
        image: ml-platform/trainer:latest
        command: ["python", "train_model.py"]
        resources:
          requests:
            nvidia.com/gpu: 1
          limits:
            nvidia.com/gpu: 1
      restartPolicy: Never
EOF
```

#### Model Deployment

```bash
# 1. Build model image
docker build -t ml-platform/model-serving:v1.0.0 .

# 2. Test locally
docker run -p 8080:8080 ml-platform/model-serving:v1.0.0

# 3. Deploy to cluster
kubectl apply -f infrastructure/kubernetes/base/app-ml-platform/model-serving.yaml

# 4. Test deployment
kubectl port-forward svc/model-serving 8080:80 -n app-ml-team
curl http://localhost:8080/predict -d '{"features": [1,2,3,4]}'
```

### Data Team (Data Engineering)

#### Data Pipeline Development

```bash
# 1. Start data services
kubectl port-forward svc/kafka 9092:9092 -n app-data-team
kubectl port-forward svc/spark-master 8080:8080 -n app-data-team

# 2. Develop pipeline locally
cd src/data-processing/
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Test pipeline
python -m pytest tests/data/
python pipeline.py --config local.yaml

# 4. Deploy as CronJob
kubectl apply -f infrastructure/kubernetes/base/app-data-platform/data-processing-cronjob.yaml
```

#### Data Quality Monitoring

```bash
# 1. Run data quality checks
python data_quality_checks.py

# 2. View results in Grafana
kubectl port-forward svc/grafana 3000:80 -n data-platform-monitoring

# 3. Set up alerts
kubectl apply -f infrastructure/kubernetes/base/monitoring/data-quality-alerts.yaml
```

## 🔧 Development Tools & Utilities

### Essential Commands

#### Cluster Management

```bash
# Switch between contexts
kubectl config use-context kind-gigifokchiman

# Quick cluster status
kubectl get nodes,ns,pods -A

# Resource usage
kubectl top nodes
kubectl top pods -A

# Clean up resources
kubectl delete pods --field-selector=status.phase=Succeeded -A
```

#### Application Debugging

```bash
# Get application logs
kubectl logs -f deployment/backend -n app-core-team

# Debug pod issues
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port forward for debugging
kubectl port-forward pod/<pod-name> 8080:8080 -n <namespace>
```

#### Database Operations

```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n app-core-team -- psql -U app_user -d app_db

# Backup database
kubectl exec deployment/postgres -n app-core-team -- pg_dump -U app_user app_db > backup.sql

# Restore database
kubectl exec -i deployment/postgres -n app-core-team -- psql -U app_user -d app_db < backup.sql
```

### Development Environment Setup

#### Local Environment Variables

```bash
# .env file for local development
export KUBECONFIG=~/.kube/config
export KUBECTL_CONTEXT=kind-gigifokchiman
export NAMESPACE=app-core-team

# Add to .bashrc or .zshrc
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'
alias klog='kubectl logs -f'
alias kdesc='kubectl describe'
```

#### IDE Configuration

#### VS Code Extensions

```json
{
  "recommendations": [
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "hashicorp.terraform",
    "redhat.vscode-yaml",
    "ms-python.python",
    "ms-vscode.vscode-typescript-next",
    "ms-vscode-remote.remote-containers"
  ]
}
```

#### IntelliJ IDEA Plugins

- Kubernetes
- Terraform and HCL
- Docker
- Python
- JavaScript and TypeScript

### Code Quality Tools

#### Pre-commit Hooks Setup

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

#### Linting and Formatting

```bash
# Python
black src/
isort src/
flake8 src/
mypy src/

# TypeScript/JavaScript
npm run lint
npm run format

# Terraform
terraform fmt -recursive infrastructure/
tflint infrastructure/terraform/

# Kubernetes YAML
kubeval infrastructure/kubernetes/base/
```

## 🚀 Deployment Workflows

### GitOps with ArgoCD

#### Application Deployment

```bash
# 1. Create ArgoCD application
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-application
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourorg/implement-ml-p
    targetRevision: HEAD
    path: infrastructure/kubernetes/base/app-my-service
  destination:
    server: https://kubernetes.default.svc
    namespace: app-core-team
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# 2. Monitor deployment
argocd app get my-application
argocd app sync my-application
```

#### Manual Deployment (Emergency Only)

```bash
# Deploy directly (bypasses GitOps)
kubectl apply -k infrastructure/kubernetes/overlays/local/
```

### Environment Promotion

#### Local → Dev

```bash
# 1. Test locally
make test-all

# 2. Merge to develop branch
git checkout develop
git merge feature/my-feature

# 3. ArgoCD automatically deploys to dev environment
```

#### Dev → Staging → Production

```bash
# 1. Create release branch
git checkout -b release/v1.2.0

# 2. Update version tags
sed -i 's/image: app:latest/image: app:v1.2.0/' infrastructure/kubernetes/overlays/staging/

# 3. Manual promotion with approval
argocd app sync my-application-staging
argocd app sync my-application-prod
```

## 🔍 Monitoring & Debugging

### Application Monitoring

#### Metrics Collection

```bash
# View Prometheus metrics
kubectl port-forward svc/prometheus 9090:9090 -n data-platform-monitoring

# View Grafana dashboards
kubectl port-forward svc/grafana 3000:80 -n data-platform-monitoring
```

#### Log Aggregation

```bash
# View centralized logs
kubectl port-forward svc/kibana 5601:5601 -n data-platform-performance

# Search logs with kubectl
kubectl logs -l app=backend -n app-core-team --tail=100
```

#### Distributed Tracing

```bash
# View Jaeger traces
kubectl port-forward svc/jaeger 16686:16686 -n data-platform-performance

# Add tracing to your application
import jaeger_client

config = jaeger_client.Config(
    config={
        'sampler': {'type': 'const', 'param': 1},
        'logging': True,
    },
    service_name='my-service',
)
tracer = config.initialize_tracer()
```

### Performance Optimization

#### Resource Optimization

```bash
# Check resource usage
kubectl top pods -n app-core-team
kubectl describe nodes

# Optimize resource requests/limits
kubectl patch deployment backend -n app-core-team -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "backend",
          "resources": {
            "requests": {"cpu": "100m", "memory": "128Mi"},
            "limits": {"cpu": "500m", "memory": "512Mi"}
          }
        }]
      }
    }
  }
}'
```

#### Scaling Applications

```bash
# Manual scaling
kubectl scale deployment backend --replicas=3 -n app-core-team

# Horizontal Pod Autoscaler
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: app-core-team
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF
```

## 📚 Additional Resources

### Documentation

- [Architecture Overview](../ARCHITECTURE.md)
- [Security Guide](../SECURITY-COMPREHENSIVE-GUIDE.md)
- [Operations Manual](../operations/OPERATIONAL-RUNBOOKS.md)
- [Testing Guide](../reference/TESTING-GUIDE.md)

### External Tools

- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Terraform CLI](https://www.terraform.io/docs/cli/index.html)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

### Community Resources

- [Platform Engineering Slack](https://yourorg.slack.com/channels/platform-engineering)
- [ML Team Slack](https://yourorg.slack.com/channels/ml-team)
- [Data Team Slack](https://yourorg.slack.com/channels/data-team)

---

*This guide is maintained by the Platform Engineering team. For questions or improvements, create an issue or reach out
on Slack.*
