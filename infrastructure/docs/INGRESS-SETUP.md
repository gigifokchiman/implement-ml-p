# Ingress Setup Guide

This guide explains how to set up TLS ingress for the ML Platform services.

## Overview

The ML Platform uses NGINX Ingress Controller with TLS termination to route traffic to various services:

- **Frontend**: `ml-platform.local`
- **Backend API**: `api.ml-platform.local`
- **ML Service**: `ml.ml-platform.local`
- **Prometheus**: `prometheus.ml-platform.local`
- **Grafana**: `grafana.ml-platform.local`

## Prerequisites

1. Kind cluster with NGINX Ingress Controller (installed via `make setup-cluster`)
2. DNS resolution for local domains
3. TLS certificates

## Quick Setup

### 1. Generate TLS Certificates

```bash
# Navigate to Kind sandbox directory
cd infrastructure/kind/sandbox

# Create directories
mkdir -p auth certs registry-data

# Generate self-signed certificate for local development
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/domain.key \
  -out certs/domain.crt \
  -subj "/C=US/ST=CA/L=SF/O=ML-Platform/CN=*.ml-platform.local"

# Create certificates for multiple domains
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/ml-platform.key \
  -out certs/ml-platform.crt \
  -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = SF
O = ML-Platform
CN = ml-platform.local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ml-platform.local
DNS.2 = api.ml-platform.local
DNS.3 = ml.ml-platform.local
DNS.4 = prometheus.ml-platform.local
DNS.5 = grafana.ml-platform.local
EOF
)
```

### 2. Create Kubernetes TLS Secrets

```bash
# Create TLS secret for ML Platform services
kubectl create secret tls ml-platform-tls-secret \
  --cert=certs/ml-platform.crt \
  --key=certs/ml-platform.key \
  --namespace=ml-platform

# Create TLS secret for monitoring services  
kubectl create secret tls monitoring-tls-secret \
  --cert=certs/ml-platform.crt \
  --key=certs/ml-platform.key \
  --namespace=monitoring

# Create basic auth secret for monitoring (optional)
htpasswd -bc auth/htpasswd admin password
kubectl create secret generic monitoring-basic-auth \
  --from-file=auth=auth/htpasswd \
  --namespace=monitoring
```

### 3. Configure Local DNS

Add these entries to your `/etc/hosts` file:

```bash
# ML Platform local domains
127.0.0.1 ml-platform.local
127.0.0.1 api.ml-platform.local
127.0.0.1 ml.ml-platform.local
127.0.0.1 prometheus.ml-platform.local
127.0.0.1 grafana.ml-platform.local
```

### 4. Deploy Ingress Resources

```bash
# Deploy using Kustomize
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Or deploy individual resources
kubectl apply -f infrastructure/kubernetes/base/network/ml-platform-ingress.yaml
kubectl apply -f infrastructure/kubernetes/base/network/monitoring-ingress.yaml
kubectl apply -f infrastructure/kubernetes/base/security/tls-secrets.yaml
```

## Verification

### Check Ingress Status
```bash
# List ingresses
kubectl get ingress -A

# Check ingress details
kubectl describe ingress ml-platform-ingress -n ml-platform

# Check NGINX controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Test Connectivity
```bash
# Test HTTPS endpoints (accept self-signed certs)
curl -k https://ml-platform.local
curl -k https://api.ml-platform.local/docs
curl -k https://ml.ml-platform.local/health
curl -k https://prometheus.ml-platform.local
curl -k https://grafana.ml-platform.local
```

## Configuration Files

### Ingress Resources
- `infrastructure/kubernetes/base/network/ml-platform-ingress.yaml` - Main application ingress
- `infrastructure/kubernetes/base/network/monitoring-ingress.yaml` - Monitoring tools ingress

### Security
- `infrastructure/kubernetes/base/security/tls-secrets.yaml` - TLS certificate secrets

### Environment Overlays
- `infrastructure/kubernetes/overlays/dev/` - Development environment patches
- `infrastructure/kubernetes/overlays/prod/` - Production environment (to be created)

## Environment-Specific Configuration

### Development
- Relaxed rate limiting (1000 req/min)
- No basic auth for monitoring
- Debug headers enabled

### Production (Future)
- Strict rate limiting (100 req/min)
- Basic auth for monitoring
- Security headers enforced
- Real TLS certificates from Let's Encrypt

## Troubleshooting

### Common Issues

1. **503 Service Unavailable**
   - Check if backend services are running
   - Verify service names and ports in ingress

2. **SSL Certificate Errors**
   - Ensure TLS secrets exist in correct namespaces
   - Check certificate validity and SAN entries

3. **DNS Resolution Issues**
   - Verify `/etc/hosts` entries
   - Check ingress controller external IP

### Debug Commands
```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx

# View ingress events
kubectl get events -n ml-platform --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints -n ml-platform

# Test internal service connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- /bin/sh
# Inside pod: curl http://backend-service.ml-platform.svc.cluster.local:8000
```

## Security Considerations

1. **TLS Certificates**: Use proper CA-signed certificates in production
2. **Basic Authentication**: Enable for monitoring tools in production
3. **Rate Limiting**: Adjust limits based on expected traffic
4. **Network Policies**: Implement network segmentation
5. **WAF**: Consider adding Web Application Firewall rules

## Integration with Services

The ingress configurations assume the following services exist:

- `frontend-service:3000` (ml-platform namespace)
- `backend-service:8000` (ml-platform namespace)  
- `ml-service:8001` (ml-platform namespace)
- `prometheus-service:9090` (monitoring namespace)
- `grafana-service:3000` (monitoring namespace)

Ensure these services are deployed before applying ingress configurations.