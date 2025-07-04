# Monitoring Scripts

Scripts for deploying team-specific monitoring, observability, and compliance checking.

## Scripts

- **`deploy-team-monitoring.sh`** - Deploy ServiceMonitors and PrometheusRules for team metrics
- **`check-resource-labels.sh`** - Validate resource labels for compliance and cost tracking

## Prerequisites

- ArgoCD deployed with Prometheus CRDs
- Prometheus Operator running in the cluster

## What It Provides

- **ServiceMonitors** for each team namespace (ml-team, data-team, app-team)
- **PrometheusRules** for resource quota alerts
- **Team dashboards** in Grafana
- **Quota usage alerts** when teams approach limits

## Usage

Run this after ArgoCD deployment to enable team monitoring:

```bash
./deploy-team-monitoring.sh
```

Access Grafana at `http://localhost:3000` (admin/prom-operator) to view team dashboards.

## Label Compliance Checking

The `check-resource-labels.sh` script validates that resources have proper labels applied by Terraform and Kubernetes
manifests.

### Usage

```bash
# Check label compliance on default cluster
./check-resource-labels.sh

# Check specific cluster
./check-resource-labels.sh kind-production-cluster
```

### What It Checks

1. **Node Labels**:
    - `environment` (production/staging/dev)
    - `cluster-name` (cluster identifier)
    - `workload-type` (ml-compute/data-processing/application)

2. **Namespace Labels**:
    - `team` (ml-engineering/data-engineering/app-engineering)
    - `environment` (production/staging/dev)
    - `cost-center` (ml/data/app)
    - `workload-type` (optional)

3. **Service Labels**:
    - `app.kubernetes.io/name` (service name)
    - `app.kubernetes.io/component` (component type)

### Compliance Report

The script provides:

- Total checks performed
- Pass/fail counts
- Compliance percentage
- Actionable feedback on missing labels

This helps ensure cost tracking, security policies, and operational governance are properly implemented through
infrastructure as code.
