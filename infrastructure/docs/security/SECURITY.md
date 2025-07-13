# Security Configuration

This document outlines how to securely configure the ML Platform infrastructure.

## 🔒 **Credentials Management**

### **Environment Variables**

Set the following environment variables for secure operation:

```bash
# Registry Authentication
export REGISTRY_USERNAME=your-username
export REGISTRY_PASSWORD=your-secure-password

# Database Configuration (local development)
export DB_USERNAME=postgres
export DB_PASSWORD=your-db-password
export DB_NAME=ml_platform

# Redis Configuration
export REDIS_PASSWORD=your-redis-password

# MinIO Configuration
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=your-minio-password
```

### **Configuration Files**

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with secure passwords:**
   ```bash
   # Don't use default passwords in production!
   REGISTRY_PASSWORD=generate-secure-password-here
   DB_PASSWORD=another-secure-password
   MINIO_ROOT_PASSWORD=yet-another-secure-password
   ```

3. **The `.env` file is git-ignored for security**

## 🚀 **Deployment**

### **Local Development**

```bash
# Source environment variables
source .env

# Deploy with secure credentials
make dev-kind-up
```

### **Production**

- Use proper secret management (AWS Secrets Manager, HashiCorp Vault, etc.)
- Never commit passwords to git
- Use least-privilege access principles
- Rotate credentials regularly

## ⚠️ **Security Best Practices**

1. **Never use default passwords**
2. **Use strong, unique passwords for each service**
3. **Rotate credentials regularly**
4. **Use environment-specific credentials**
5. **Enable audit logging in production**
6. **Use TLS/SSL for all external communications**

## 🔍 **Credential Locations**

| Service      | Configuration Method                        |
|--------------|---------------------------------------------|
| **Registry** | Environment variables → Terraform variables |
| **Database** | Kubernetes secretGenerator                  |
| **MinIO**    | Kubernetes secretGenerator                  |
| **Redis**    | Kubernetes secretGenerator                  |

## 🚨 **Default Credentials Removed**

All hardcoded credentials have been removed from:

- ✅ Terraform configurations
- ✅ Kubernetes manifests
- ✅ Makefile commands
- ✅ Documentation

Default values are now configurable via environment variables.
