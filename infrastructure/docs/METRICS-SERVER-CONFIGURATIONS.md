# Metrics Server Configuration Guide

This guide explains the different metrics-server configurations available for development and production environments.

## Overview

The ML Platform provides two metrics-server configurations:
- **Development**: Relaxed security for local Kind clusters
- **Production**: Strict TLS verification for production environments

## Configuration Comparison

| Feature | Development | Production |
|---------|-------------|------------|
| **TLS Verification** | Disabled (`--kubelet-insecure-tls`) | Enabled with proper certificates |
| **Logging Level** | Verbose (`--v=2`) | Standard (`--v=1`) |
| **Resource Limits** | Lower (200m CPU, 300Mi RAM) | Higher (1000m CPU, 1Gi RAM) |
| **Security Context** | Basic | Enhanced with TLS cipher suites |
| **Monitoring** | Basic health checks | ServiceMonitor for Prometheus |
| **Certificate Management** | None required | Custom TLS certificates |

## Development Configuration

### Features
- **Quick setup** - No certificate generation required
- **Insecure TLS** - Skips kubelet certificate verification
- **Verbose logging** - Easier debugging
- **Lower resource usage** - Suitable for local development

### Usage
```bash
# Development cluster setup
make setup-cluster

# Or install just metrics-server in dev mode
make install-metrics-server-dev
```

### Configuration File
`metrics-server-dev.yaml` includes:
```yaml
args:
  - --kubelet-insecure-tls
  - --v=2
resources:
  limits:
    cpu: 200m
    memory: 300Mi
```

## Production Configuration

### Features
- **Secure TLS** - Full certificate verification
- **Production logging** - Reduced verbosity
- **Higher resources** - Better performance
- **TLS cipher suites** - Specific security algorithms
- **Anti-affinity** - Pod distribution across nodes
- **Prometheus integration** - ServiceMonitor included

### Usage
```bash
# Production cluster setup
make setup-cluster-prod

# Or install just metrics-server in prod mode
make install-metrics-server-prod

# Generate certificates manually
make generate-metrics-certs
```

### Configuration File
`metrics-server-prod.yaml` includes:
```yaml
args:
  - --kubelet-certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  - --tls-cert-file=/etc/certs/tls.crt
  - --tls-private-key-file=/etc/certs/tls.key
  - --tls-min-version=VersionTLS12
  - --v=1
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
```

## Certificate Management

### Automatic Generation
The production setup automatically generates certificates when needed:

```bash
# Generates certificates if they don't exist
make install-metrics-server-prod
```

### Manual Certificate Generation
```bash
# Generate certificates manually
make generate-metrics-certs

# Files created:
# - certs/metrics-server.crt
# - certs/metrics-server.key  
# - certs/metrics-server-secret.yaml
```

### Certificate Details
Generated certificates include:
- **Subject**: `metrics-server.kube-system.svc.cluster.local`
- **SAN entries**:
  - `metrics-server`
  - `metrics-server.kube-system`
  - `metrics-server.kube-system.svc`
  - `metrics-server.kube-system.svc.cluster.local`
  - `127.0.0.1`
- **Validity**: 365 days
- **Key size**: 2048 bits RSA

## Verification

### Check Metrics Server Status
```bash
# Check pod status
kubectl get pods -n kube-system | grep metrics-server

# Check logs
kubectl logs -n kube-system deployment/metrics-server

# Test metrics endpoint
kubectl top nodes
kubectl top pods -A
```

### Development Mode Verification
```bash
# Should show insecure TLS in logs
kubectl logs -n kube-system deployment/metrics-server | grep "insecure"
```

### Production Mode Verification
```bash
# Should show TLS certificate paths in logs
kubectl logs -n kube-system deployment/metrics-server | grep "tls-cert"

# Check certificate secret
kubectl get secret metrics-server-certs -n kube-system
```

## Troubleshooting

### Common Issues

#### 1. Development Mode - Certificate Errors
If you see certificate verification errors in dev mode:
```bash
# Ensure the dev configuration is applied
kubectl apply -f metrics-server-dev.yaml
```

#### 2. Production Mode - Missing Certificates
```bash
# Check if certificates exist
ls -la certs/metrics-server*

# Regenerate if missing
make generate-metrics-certs
kubectl apply -f certs/metrics-server-secret.yaml
```

#### 3. Metrics Not Available
```bash
# Check metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Check service endpoints
kubectl get endpoints metrics-server -n kube-system

# Verify API server can reach metrics-server
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
```

### Debug Commands
```bash
# View detailed metrics-server configuration
kubectl describe deployment metrics-server -n kube-system

# Check certificate validity (production)
openssl x509 -in certs/metrics-server.crt -noout -text

# Test metrics endpoint directly
kubectl proxy &
curl http://localhost:8001/apis/metrics.k8s.io/v1beta1/nodes
```

## Migration Between Modes

### From Development to Production
```bash
# Delete existing dev deployment
kubectl delete deployment metrics-server -n kube-system

# Install production version
make install-metrics-server-prod
```

### From Production to Development
```bash
# Delete existing prod deployment and secrets
kubectl delete deployment metrics-server -n kube-system
kubectl delete secret metrics-server-certs -n kube-system

# Install development version
make install-metrics-server-dev
```

## Integration with Monitoring

### Development
Basic health checks only - suitable for local development.

### Production
Includes ServiceMonitor for Prometheus integration:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-server
spec:
  endpoints:
  - port: https
    scheme: https
    tlsConfig:
      insecureSkipVerify: false
```

## Security Considerations

### Development
- ⚠️ **Insecure TLS** - Only use in trusted local environments
- ⚠️ **Verbose logging** - May expose sensitive information
- ✅ **Resource limits** - Prevents resource exhaustion

### Production
- ✅ **Full TLS verification** - Secure communication
- ✅ **Certificate rotation** - 365-day validity with renewal
- ✅ **TLS cipher suites** - Modern cryptographic algorithms
- ✅ **Pod anti-affinity** - High availability deployment
- ✅ **Minimal logging** - Reduced information exposure