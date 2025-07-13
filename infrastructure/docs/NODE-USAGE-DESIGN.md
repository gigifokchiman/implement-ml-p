# Node Usage Design Guide

## Overview

This guide explains the node architecture and workload placement strategy for the data platform.

## Node Architecture Options

### Option 1: Three-Node Cluster (Recommended)

Best for production-like environments with clear separation of concerns.

```
┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐
│   Control Plane Node    │     │   Infrastructure Node   │     │    Workload Node        │
├─────────────────────────┤     ├─────────────────────────┤     ├─────────────────────────┤
│ • Kubernetes API Server │     │ • Prometheus/Grafana    │     │ • ML Applications       │
│ • etcd                  │     │ • ArgoCD                │     │ • Data Processing       │
│ • Controller Manager    │     │ • Cert Manager          │     │ • User Applications     │
│ • Scheduler             │     │ • PostgreSQL/Redis      │     │ • GPU Workloads         │
│ • CoreDNS               │     │ • MinIO Storage         │     │ • Batch Jobs            │
│ • Ingress Controller    │     │ • Jaeger                │     │                         │
└─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘
```

### Option 2: Two-Node Cluster

For resource-constrained environments.

```
┌─────────────────────────┐     ┌─────────────────────────┐
│ Control Plane + Infra   │     │    Workload Node        │
├─────────────────────────┤     ├─────────────────────────┤
│ • All System Components │     │ • All Applications      │
│ • ArgoCD                │     │ • Monitoring Stack      │
│ • Cert Manager          │     │ • Databases             │
│ • Ingress               │     │ • GPU Workloads         │
└─────────────────────────┘     └─────────────────────────┘
```

### Option 3: Single-Node Cluster

For minimal local development only.

## Implementation

### 1. Apply Three-Node Configuration

```bash
# Backup current config
cp infrastructure/terraform/environments/local/main.tf \
   infrastructure/terraform/environments/local/main-backup.tf

# Use three-node config
cp infrastructure/terraform/environments/local/main-three-nodes.tf \
   infrastructure/terraform/environments/local/main.tf

# Apply changes
cd infrastructure/terraform/environments/local
terraform destroy -auto-approve
terraform apply -auto-approve
```

### 2. Node Labels and Taints

#### Control Plane Node

```yaml
labels:
  node-role: control-plane
  ingress-ready: "true"
taints:
  - key: node-role.kubernetes.io/control-plane
    effect: NoSchedule
```

#### Infrastructure Node

```yaml
labels:
  node-role: infra
  environment: local
```

#### Workload Node

```yaml
labels:
  node-role: workload
  workload-type: data-processing
  gpu: "available"  # if GPU present
```

### 3. Workload Placement Examples

#### Monitoring Stack (Prometheus/Grafana)

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: node-role
            operator: In
            values: ["infra"]
  priorityClassName: infrastructure-high
```

#### ML/Data Applications

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: node-role
            operator: In
            values: ["workload"]
  priorityClassName: workload-default
```

#### GPU Workloads

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: gpu
            operator: In
            values: ["available"]
  resources:
    limits:
      nvidia.com/gpu: 1
```

## Resource Recommendations

### Control Plane Node

- **CPU**: 2 cores
- **Memory**: 4GB
- **Disk**: 20GB

### Infrastructure Node

- **CPU**: 4 cores
- **Memory**: 8GB
- **Disk**: 50GB (for monitoring data)

### Workload Node

- **CPU**: 4-8 cores
- **Memory**: 16-32GB
- **Disk**: 100GB+
- **GPU**: Optional, based on ML workload needs

## Monitoring Node Usage

```bash
# View node capacity and allocation
kubectl describe nodes

# View pods by node
kubectl get pods --all-namespaces -o wide

# View node resource usage (requires metrics-server)
kubectl top nodes

# Check node labels
kubectl get nodes --show-labels
```

## Troubleshooting

### Pods Not Scheduling

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check node taints
kubectl describe node <node-name> | grep Taints

# Check available resources
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

### Rebalancing Workloads

```bash
# Cordon node to prevent new pods
kubectl cordon <node-name>

# Drain node to move pods
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node
kubectl uncordon <node-name>
```

## Best Practices

1. **Use Node Affinity** instead of node selectors for flexibility
2. **Set Resource Requests/Limits** on all workloads
3. **Use Priority Classes** to ensure critical services get resources
4. **Monitor Node Pressure** conditions regularly
5. **Plan for Node Failures** - ensure critical services have replicas

## Migration Path

To migrate from current setup to three-node:

1. Export any persistent data
2. Document current pod placements
3. Apply new terraform configuration
4. Restore data and verify services
5. Apply node affinity rules gradually

## Future Considerations

- **Auto-scaling**: Consider cluster autoscaler for dynamic workloads
- **Node Pools**: Use different instance types for different workload types
- **Spot Instances**: Use for non-critical batch workloads
- **GPU Nodes**: Add dedicated GPU nodes for ML training
