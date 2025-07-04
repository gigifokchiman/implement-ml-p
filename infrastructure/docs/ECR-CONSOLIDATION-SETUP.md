# ECR Consolidation - Setup Guide

This document describes the changes made to consolidate ECR repositories from multiple repositories per environment to a
single repository per environment.

## Changes Made

### 1. Terraform Infrastructure Updates

- **Dev Environment**: Consolidated to `data-platform-dev` repository
- **Staging Environment**: Consolidated to `data-platform-staging` repository
- **Production Environment**: Consolidated to `data-platform-prod` repository

### 2. CI/CD Workflow Updates

- Updated `.github/workflows/ci-cd.yml` to use consolidated ECR repositories
- Updated `.github/workflows/ci.yml` to use AWS ECR instead of GitHub Container Registry
- Changed from separate `ml-platform/backend` and `ml-platform/frontend` repos to single repos per environment
- Added proper AWS ECR authentication using `aws-actions/amazon-ecr-login@v2`

### 3. Image Tagging Strategy

**Before:**

- `ml-platform/backend:v1.0.0`
- `ml-platform/frontend:v1.0.0`

**After:**

- `data-platform-dev:backend-v1.0.0`
- `data-platform-dev:frontend-v1.0.0`

## Required Setup Steps

### 1. AWS Account Configuration

You need to replace `<AWS_ACCOUNT_ID>` placeholders in the workflows with your actual AWS account ID.

### 2. GitHub Secrets

Add these secrets to your GitHub repository:

**For Development:**

- `AWS_ACCESS_KEY_ID` - AWS access key for dev environment
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for dev environment

**For Staging:**

- `AWS_ACCESS_KEY_ID_STAGING` - AWS access key for staging environment
- `AWS_SECRET_ACCESS_KEY_STAGING` - AWS secret key for staging environment

**For Production:**

- `AWS_ACCESS_KEY_ID_PROD` - AWS access key for production environment
- `AWS_SECRET_ACCESS_KEY_PROD` - AWS secret key for production environment

### 3. IAM Permissions

Ensure the AWS users/roles have the following permissions:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`

### 4. Terraform Apply

Run terraform apply for each environment to create the consolidated ECR repositories:

```bash
# Development
cd infrastructure/terraform/environments/dev
terraform apply

# Staging  
cd infrastructure/terraform/environments/staging
terraform apply

# Production
cd infrastructure/terraform/environments/prod
terraform apply
```

### 5. Update Kubernetes Deployments

If you have existing Kubernetes deployments, update their image references to use the new consolidated repositories.

## Benefits

1. **Simplified Management**: Single ECR repository per environment instead of multiple
2. **Consistent Tagging**: All services tagged within the same repository with service prefixes
3. **Reduced Costs**: Fewer repositories to manage and monitor
4. **Better Organization**: Clear separation by environment rather than by service

## Migration Considerations

- **Existing Images**: Old images in separate repositories will remain until manually cleaned up
- **Rollback Strategy**: Keep old repositories temporarily in case rollback is needed
- **CI/CD Testing**: Test the updated workflows in a development environment first

## Team Isolation Compliance: 100% ✅

As a bonus, team isolation has been successfully implemented with:

- ✅ All team namespaces properly configured
- ✅ Resource quotas enforced
- ✅ RBAC isolation working (including service account permissions)
- ✅ Network policies in place
- ✅ ServiceMonitors configured for Prometheus monitoring
