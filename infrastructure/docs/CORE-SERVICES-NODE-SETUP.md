# Core Services Node Configuration

## Overview

The worker node is now configured as a **core-services-node** for running essential infrastructure services like
monitoring, databases, caching, and other platform components.

## Node Configuration

### Terraform Configuration

```hcl
node {
  role = "worker"

  kubeadm_config_patches = [
    <<-EOT
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=local,cluster-name=data-platform-local,node-role=core-services,service-type=infrastructure"
    EOT
  ]
}
```

### Node Labels

- `environment=local` - Environment identifier
- `cluster-name=data-platform-local` - Cluster name
- `node-role=core-services` - Identifies this as core services node
- `service-type=infrastructure` - Type of services running

### No Taints

The core-services node has **no taints**, meaning:

- ✅ All workloads can schedule here by default
- ✅ No special tolerations needed
- ✅ Acts as the general-purpose worker node

## Current Architecture

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│      Control Plane Node         │     │     Core Services Node          │
│   (data-platform-local-cp)      │     │   (data-platform-local-worker)  │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│ 🔒 TAINTED                      │     │ ✅ UNTAINTED                    │
│                                 │     │                                 │
│ Taint:                          │     │ Labels:                         │
│ • control-plane:NoSchedule      │     │ • node-role=core-services       │
│                                 │     │ • service-type=infrastructure   │
│ Workloads:                      │     │                                 │
│ • Kubernetes system components  │     │ Workloads:                      │
│ • etcd                          │     │ • Monitoring (Prometheus)       │
│ • API server                    │     │ • ArgoCD                        │
│ • Controller manager            │     │ • Cert Manager                  │
│ • Scheduler                     │     │ • Databases (PostgreSQL)        │
│ • CoreDNS                       │     │ • Cache (Redis)                 │
│ • Ingress controller            │     │ • Storage (MinIO)               │
│                                 │     │ • Team applications             │
│ Resources: 2 CPU, 4GB RAM       │     │ • General workloads             │
│                                 │     │                                 │
│                                 │     │ Resources: 4-8 CPU, 8-16GB RAM │
└─────────────────────────────────┘     └─────────────────────────────────┘
```

## Workload Scheduling

### Core Services (Preferred on Core Services Node)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node-role
                operator: In
                values: ["core-services"]
      containers:
      - name: prometheus
        image: prom/prometheus:latest
```

### General Workloads (No Special Requirements)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-app
spec:
  template:
    spec:
      # No node affinity needed - will schedule on core-services node
      containers:
      - name: app
        image: nginx:latest
```

### System Components (Must Tolerate Control Plane)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-agent
spec:
  template:
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      # Runs on both nodes
```

## Benefits of Core Services Node

1. **Dedicated Resources**: Core services get dedicated compute
2. **No Competition**: System components isolated on control plane
3. **Flexible Scheduling**: No taints mean easy workload placement
4. **Clear Separation**: Infrastructure vs system components

## Typical Services on Core Services Node

### Monitoring Stack

- Prometheus
- Grafana
- AlertManager
- Metrics Server

### GitOps

- ArgoCD
- Flux (if used)

### Security

- Cert Manager
- External Secrets Operator
- OPA/Gatekeeper

### Data Services

- PostgreSQL
- Redis
- MinIO/S3-compatible storage

### Team Applications

- ML team apps (when not using GPU)
- Data team apps
- Core team apps

## Migration from GPU Node

If you previously had GPU workloads:

1. **Remove GPU tolerations** from deployments
2. **Remove GPU resource requests**
3. **Update node affinity** to prefer core-services
4. **Redeploy workloads**

Example migration:

```yaml
# Before (GPU node)
tolerations:
- key: apple.com/gpu
  value: present
  effect: NoSchedule
resources:
  requests:
    apple.com/gpu: 1

# After (Core services node)
# No tolerations needed
# No GPU resources
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: node-role
          operator: In
          values: ["core-services"]
```

## Commands to Verify

```bash
# Check node labels
kubectl get nodes --show-labels

# See workload distribution
kubectl get pods --all-namespaces -o wide

# Check node resources
kubectl describe node data-platform-local-worker

# View pods on core services node
kubectl get pods --all-namespaces --field-selector spec.nodeName=data-platform-local-worker
```

The core services node is now ready to host all your infrastructure services! 🚀
