# GPU Node Management with ArgoCD

## Overview

This guide explains how to manage additional GPU nodes through ArgoCD for your two-node cluster setup.

## Current Architecture

```
┌─────────────────────────┐     ┌─────────────────────────┐
│   Control Plane Node    │     │     Worker Node         │
│      (TAINTED)          │     │                         │
├─────────────────────────┤     ├─────────────────────────┤
│ • API Server            │     │ • All Applications      │
│ • etcd                  │     │ • Monitoring            │
│ • Controller Manager    │     │ • Databases             │
│ • Scheduler             │     │ • GPU Workloads         │
│ • CoreDNS               │     │ • ArgoCD                │
│ • Ingress Controller    │     │ • Cert Manager          │
│                         │     │                         │
│ Resources: 2 CPU, 4GB   │     │ Resources: 4-8 CPU,     │
│ Taint: NoSchedule       │     │           8-16GB RAM    │
└─────────────────────────┘     └─────────────────────────┘
```

## Adding GPU Nodes via ArgoCD

### 1. ArgoCD Applications Created

#### GPU Node Management App (`gpu-nodes`)

- **Path**: `infrastructure/kubernetes/gpu-nodes/`
- **Purpose**: GPU node configuration and affinity rules
- **Auto-sync**: Enabled

#### NVIDIA Device Plugin App (`nvidia-device-plugin`)

- **Chart**: `nvidia/k8s-device-plugin`
- **Purpose**: GPU resource detection and allocation
- **Auto-sync**: Enabled

### 2. GPU Node Addition Process

#### Option A: Manual Node Addition (Kind Clusters)

```bash
# 1. Create new GPU-enabled container
docker run -d --gpus all --name gpu-worker-1 \
  --privileged --network kind \
  kindest/node:v1.28.0

# 2. Get join token from control plane
kubectl get secrets -n kube-system | grep bootstrap-token

# 3. Join the cluster
docker exec gpu-worker-1 kubeadm join <control-plane-ip>:6443 \
  --token <token> --discovery-token-ca-cert-hash <hash>

# 4. Label and taint the node
kubectl label node gpu-worker-1 nvidia.com/gpu.present=true
kubectl label node gpu-worker-1 node-role=gpu-worker
kubectl taint node gpu-worker-1 nvidia.com/gpu=present:NoSchedule
```

#### Option B: Terraform Managed GPU Nodes

```hcl
# Add to main.tf
node {
  role = "worker"
  
  kubeadm_config_patches = [
    <<-EOT
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "nvidia.com/gpu.present=true,node-role=gpu-worker"
      taints:
      - key: nvidia.com/gpu
        value: present
        effect: NoSchedule
    EOT
  ]
  
  # GPU support (requires Docker with nvidia-container-runtime)
  extra_mounts {
    host_path      = "/usr/local/nvidia"
    container_path = "/usr/local/nvidia"
    readonly       = true
  }
}
```

### 3. ArgoCD Configuration

#### Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gpu-nodes
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/infrastructure
    path: infrastructure/kubernetes/gpu-nodes
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### GPU Workload Scheduling

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      # Require GPU nodes
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: nvidia.com/gpu.present
              operator: In
              values: ["true"]
      
      # Tolerate GPU node taints
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      
      # Request GPU resources
      containers:
      - name: gpu-workload
        resources:
          limits:
            nvidia.com/gpu: 1
```

## ArgoCD Benefits for GPU Nodes

### 1. **GitOps Workflow**

- GPU node configs in Git
- Version controlled changes
- Automated deployment

### 2. **Declarative Management**

```bash
# Add GPU node via Git commit
git add infrastructure/kubernetes/gpu-nodes/new-gpu-node.yaml
git commit -m "Add GPU worker node for ML training"
git push

# ArgoCD automatically applies changes
```

### 3. **Resource Templates**

- Pre-configured GPU workload templates
- Priority classes for GPU scheduling
- Node affinity patterns

### 4. **Monitoring Integration**

- ArgoCD UI shows GPU node status
- Sync status and health checks
- Integration with Prometheus metrics

## GPU Node Types

### Development GPU Node

```yaml
labels:
  nvidia.com/gpu.present: "true"
  gpu-type: "development"
  node-role: "gpu-dev"
taints:
- key: "gpu-type"
  value: "development"
  effect: "NoSchedule"
```

### Production GPU Node

```yaml
labels:
  nvidia.com/gpu.present: "true"
  gpu-type: "production"
  node-role: "gpu-prod"
taints:
- key: "gpu-type"
  value: "production"
  effect: "NoSchedule"
```

### Training GPU Node

```yaml
labels:
  nvidia.com/gpu.present: "true"
  gpu-type: "training"
  node-role: "gpu-training"
taints:
- key: "gpu-type"
  value: "training"
  effect: "NoSchedule"
```

## Priority Scheduling

### High Priority (Real-time inference)

```yaml
priorityClassName: gpu-high-priority
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: gpu-type
        operator: In
        values: ["production"]
```

### Batch Priority (Training jobs)

```yaml
priorityClassName: gpu-batch-priority
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    preference:
      matchExpressions:
      - key: gpu-type
        operator: In
        values: ["training", "development"]
```

## Monitoring GPU Nodes

### ArgoCD Dashboard

- Navigate to Applications → gpu-nodes
- Check sync status and health
- View resource definitions

### Kubernetes Commands

```bash
# List GPU nodes
kubectl get nodes -l nvidia.com/gpu.present=true

# Check GPU resources
kubectl describe nodes -l nvidia.com/gpu.present=true

# View GPU pods
kubectl get pods -A -o wide --field-selector spec.nodeName=<gpu-node-name>
```

## Scaling Strategy

### 1. **On-Demand Scaling**

- Add GPU nodes when workload increases
- ArgoCD deploys node configurations
- Automatic workload scheduling

### 2. **Workload-Based Scaling**

```bash
# Scale GPU deployment
kubectl scale deployment gpu-workload --replicas=5

# ArgoCD ensures GPU nodes are properly configured
# Kubernetes scheduler places pods on GPU nodes
```

### 3. **Cost Optimization**

- Use spot instances for batch workloads
- Scale down GPU nodes during low usage
- Mixed instance types for different workloads

## Best Practices

1. **Separate GPU node pools** by workload type
2. **Use taints and tolerations** to prevent CPU workloads on GPU nodes
3. **Set resource requests/limits** to prevent resource contention
4. **Monitor GPU utilization** with nvidia-smi and Prometheus
5. **Use priority classes** for critical vs batch workloads
6. **Regular backup** of GPU node configurations in Git

## Next Steps

1. Commit GPU node configurations to Git
2. Configure ArgoCD to watch your repository
3. Add first GPU node manually or via Terraform
4. Deploy GPU workloads using provided templates
5. Monitor through ArgoCD UI and Prometheus
