# Prometheus Operator CRDs

This document explains why and how Prometheus Operator CRDs are installed in the ML Platform infrastructure.

## Why These CRDs Are Required

The ML Platform uses **ServiceMonitor** and **PodMonitor** resources for application monitoring. These are Custom
Resource Definitions (CRDs) provided by the Prometheus Operator project.

### Resources That Require CRDs:

- **ServiceMonitors**: Monitor services via service discovery
- **PodMonitors**: Monitor pods directly (useful for jobs/cronjobs)
- **PrometheusRules**: Alerting and recording rules

### Without CRDs:

- ArgoCD sync fails with "CRD not found" errors
- Monitoring resources cannot be deployed
- Applications appear as "SyncFailed" in ArgoCD

## Installation Methods

### 1. Automatic Installation (Recommended)

CRDs are automatically installed when running:

```bash
./scripts/bootstrap-argocd.sh local
```

### 2. Manual Installation

```bash
./scripts/install-prometheus-crds.sh
```

### 3. Individual CRD Installation

```bash
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
```

## Verification

Check that CRDs are installed:

```bash
kubectl get crd | grep monitoring.coreos.com
```

Expected output:

```
podmonitors.monitoring.coreos.com       2025-07-03T06:05:32Z
prometheusrules.monitoring.coreos.com   2025-07-03T06:05:32Z  
servicemonitors.monitoring.coreos.com   2025-07-03T06:05:32Z
```

## Environment Considerations

### Local Development

- CRDs are required even if Prometheus Operator isn't fully deployed
- Allows ArgoCD to sync monitoring resources without errors
- Resources will be "Healthy" but not functional until Prometheus Operator is installed

### Cloud Environments

- Full Prometheus Operator should be deployed via Helm
- CRDs are typically included in the Prometheus Operator Helm chart
- Provides complete monitoring functionality

## Troubleshooting

### ArgoCD Sync Failures

If you see errors like:

```
The Kubernetes API could not find monitoring.coreos.com/ServiceMonitor
```

**Solution**: Install the CRDs using one of the methods above.

### CRD Version Conflicts

If CRDs exist but are incompatible:

```bash
# Check CRD versions
kubectl get crd servicemonitors.monitoring.coreos.com -o yaml | grep version

# Update CRDs if needed
./scripts/install-prometheus-crds.sh
```

## Integration with Infrastructure

The CRDs are integrated into the infrastructure as follows:

1. **Bootstrap Script**: `scripts/bootstrap-argocd.sh` installs CRDs during initial setup
2. **Monitoring Base**: `kubernetes/base/monitoring/` includes CRD placeholder
3. **Terraform**: Could be extended to install CRDs via Helm provider (future enhancement)

This ensures that:

- New clusters automatically get required CRDs
- ArgoCD can sync monitoring resources successfully
- Infrastructure is reproducible and declarative
