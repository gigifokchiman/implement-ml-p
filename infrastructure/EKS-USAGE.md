# EKS Deployment Guide

This guide shows how to deploy the ML Platform to AWS EKS using the enhanced Makefile commands.

## 🏗️ **Prerequisites**

### **AWS Setup**

```bash
# Configure AWS CLI
aws configure

# Verify AWS access
aws sts get-caller-identity

# Create S3 bucket for Terraform state (one-time setup)
aws s3 mb s3://ml-platform-terraform-state --region us-west-2
```

### **Tools Required**

- AWS CLI v2
- Terraform >= 1.5.0
- kubectl >= 1.28.0
- Docker
- make

## 🚀 **Local Development (Interactive)**

### **Start EKS Development Environment**

```bash
cd infrastructure

# Deploy dev environment
make dev-aws-up
```

This will:

1. ✅ Initialize Terraform with local state
2. ✅ Create EKS cluster in us-west-2
3. ✅ Configure kubectl automatically
4. ✅ Deploy Kubernetes manifests
5. ✅ Show cluster status

### **Start EKS Staging Environment**

```bash
# Deploy staging environment
make staging-aws-up
```

### **Start EKS Production Environment**

```bash
# Deploy production (with confirmation prompt)
make prod-aws-up
```

### **Check Status**

```bash
# Check any environment status
make eks-status ENV=dev
make eks-status ENV=staging
make eks-status ENV=prod
```

### **Stop Environments**

```bash
# Stop specific environments
make dev-aws-down
make staging-aws-down
make prod-aws-down    # (with confirmation prompt)
```

## 🤖 **GitHub Actions (CI/CD)**

### **Environment Variables**

Set these in your GitHub repository secrets:

```bash
# Required secrets
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_ACCESS_KEY_ID_PROD=your-prod-access-key     # For production
AWS_SECRET_ACCESS_KEY_PROD=your-prod-secret-key # For production

# Environment variables (in workflow)
AWS_REGION=us-west-2
TF_STATE_BUCKET=ml-platform-terraform-state
```

### **GitHub Actions Commands**

**Validate Infrastructure (PR checks):**

```bash
make eks-validate ENV=dev
make eks-plan ENV=dev
```

**Deploy from GitHub Actions:**

```bash
# Deploy with remote state
make eks-github-up ENV=dev TF_STATE_BUCKET=ml-platform-terraform-state

# Check status
make eks-status ENV=dev

# Cleanup
make eks-github-down ENV=dev TF_STATE_BUCKET=ml-platform-terraform-state
```

## 📋 **Available Commands**

### **Environment Management**

| Command            | Description               | Usage                   |
|--------------------|---------------------------|-------------------------|
| `dev-aws-up`       | Start dev EKS cluster     | `make dev-aws-up`       |
| `staging-aws-up`   | Start staging EKS cluster | `make staging-aws-up`   |
| `prod-aws-up`      | Start prod EKS cluster    | `make prod-aws-up`      |
| `dev-aws-down`     | Stop dev EKS cluster      | `make dev-aws-down`     |
| `staging-aws-down` | Stop staging EKS cluster  | `make staging-aws-down` |
| `prod-aws-down`    | Stop prod EKS cluster     | `make prod-aws-down`    |

### **Utilities**

| Command                 | Description            | Usage                                |
|-------------------------|------------------------|--------------------------------------|
| `eks-status`            | Show cluster status    | `make eks-status ENV=dev`            |
| `eks-configure-kubectl` | Configure kubectl      | `make eks-configure-kubectl ENV=dev` |
| `eks-plan`              | Plan Terraform changes | `make eks-plan ENV=dev`              |
| `eks-validate`          | Validate Terraform     | `make eks-validate ENV=dev`          |

### **GitHub Actions Specific**

| Command           | Description               | Usage                          |
|-------------------|---------------------------|--------------------------------|
| `eks-github-up`   | Deploy with remote state  | `make eks-github-up ENV=dev`   |
| `eks-github-down` | Destroy with remote state | `make eks-github-down ENV=dev` |

## 🔧 **Configuration**

### **Environment Variables**

```makefile
# These can be overridden
AWS_REGION := us-west-2
TF_STATE_BUCKET := ml-platform-terraform-state
NAMESPACE := ml-platform
```

### **Override Variables**

```bash
# Use different region
make dev-aws-up AWS_REGION=eu-west-1

# Use different state bucket
make eks-github-up ENV=dev TF_STATE_BUCKET=my-custom-bucket
```

## 🌊 **Deployment Workflow**

### **Development Flow**

```bash
# 1. Local development with Kind
make dev-kind-up

# 2. Test in AWS dev environment
make dev-aws-up

# 3. Build and push images
make dev-build-push

# 4. Check logs
make dev-logs

# 5. Cleanup
make dev-aws-down
```

### **Production Flow**

```bash
# 1. Deploy to staging
make staging-aws-up

# 2. Run tests and validation
make eks-status ENV=staging

# 3. Deploy to production (with approval)
make prod-aws-up

# 4. Monitor production
make eks-status ENV=prod
```

## 🐛 **Troubleshooting**

### **Common Issues**

**1. AWS Authentication**

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check AWS region
echo $AWS_REGION
```

**2. Terraform State Issues**

```bash
# Check Terraform state bucket
aws s3 ls s3://ml-platform-terraform-state

# Manually configure kubectl
aws eks update-kubeconfig --region us-west-2 --name ml-platform-dev
```

**3. kubectl Context Issues**

```bash
# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Switch context
kubectl config use-context arn:aws:eks:us-west-2:123456789012:cluster/ml-platform-dev
```

### **Debug Commands**

```bash
# Show all paths and configuration
make debug-paths

# Show cluster information
make eks-status ENV=dev

# Check Terraform plan
make eks-plan ENV=dev
```

## 🚦 **Environment Differences**

| Environment    | Confirmation | Auto-approve | State Backend |
|----------------|--------------|--------------|---------------|
| **Dev**        | No           | Yes          | Local/Remote  |
| **Staging**    | No           | Yes          | Remote        |
| **Production** | Yes          | No           | Remote        |

## 📊 **Monitoring**

### **Check Resources**

```bash
# Get all pods
kubectl get pods -n ml-platform

# Get services
kubectl get services -n ml-platform

# Get ingress
kubectl get ingress -n ml-platform

# Check logs
kubectl logs -f deployment/backend -n ml-platform
```

### **AWS Console**

- **EKS Clusters**: AWS Console → EKS → Clusters
- **Load Balancers**: AWS Console → EC2 → Load Balancers
- **Auto Scaling**: AWS Console → EC2 → Auto Scaling Groups

## 🔒 **Security Best Practices**

1. **Use separate AWS accounts** for prod/non-prod
2. **Use IAM roles** instead of access keys when possible
3. **Enable CloudTrail** for audit logging
4. **Use AWS Secrets Manager** for sensitive data
5. **Regular security scans** with tools like Checkov

## 💰 **Cost Management**

```bash
# Check instance types and costs
make eks-status ENV=dev

# Stop dev environment when not needed
make dev-aws-down

# Use spot instances for dev/staging (configure in Terraform)
```

Remember to stop development environments when not in use to avoid unnecessary AWS charges! 💡
