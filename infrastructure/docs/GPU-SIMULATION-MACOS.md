# GPU Simulation on macOS with Kind

## Overview

While macOS doesn't support NVIDIA GPUs directly, you can simulate GPU environments for testing Kubernetes GPU
scheduling and workload patterns.

## Simulation Options

### Option 1: Mock GPU Device Plugin (Recommended)

Simulates GPU resources without actual hardware.

```yaml
# Mock GPU device plugin
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: mock-gpu-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: mock-gpu-device-plugin
  template:
    metadata:
      labels:
        name: mock-gpu-device-plugin
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: mock-gpu-device-plugin
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          # Create mock GPU socket
          mkdir -p /var/lib/kubelet/device-plugins
          cat > /var/lib/kubelet/device-plugins/nvidia.sock << EOF
          # Mock NVIDIA GPU socket
          EOF
          
          # Register mock GPUs
          echo "Registering 2 mock GPUs"
          sleep infinity
        securityContext:
          privileged: true
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

### Option 2: Extended Resource Simulation

Uses Kubernetes extended resources to simulate GPUs.

```yaml
# Patch node to advertise mock GPUs
apiVersion: v1
kind: Node
metadata:
  name: data-platform-local-worker
  labels:
    nvidia.com/gpu.present: "true"
    nvidia.com/gpu.family: "mock"
    gpu-simulation: "enabled"
spec:
  capacity:
    nvidia.com/gpu: "2"  # Advertise 2 mock GPUs
  allocatable:
    nvidia.com/gpu: "2"
```

### Option 3: CPU-based GPU Simulation

Run GPU workloads on CPU with simulation flags.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-gpu-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mock-gpu-workload
  template:
    metadata:
      labels:
        app: mock-gpu-workload
    spec:
      nodeAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
            - key: gpu-simulation
              operator: In
              values: ["enabled"]
      containers:
      - name: gpu-simulator
        image: python:3.9-slim
        command:
        - python
        - -c
        - |
          import time
          import os
          
          print("🚀 Starting GPU simulation...")
          print(f"Simulated GPU: {os.environ.get('NVIDIA_VISIBLE_DEVICES', 'CPU-MOCK')}")
          print("Running ML workload simulation...")
          
          # Simulate GPU workload
          for epoch in range(10):
              print(f"Epoch {epoch+1}/10 - Simulating training...")
              time.sleep(2)  # Simulate processing time
          
          print("✅ GPU simulation completed!")
          time.sleep(3600)  # Keep container running
        env:
        - name: NVIDIA_VISIBLE_DEVICES
          value: "mock-gpu-0"
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
            nvidia.com/gpu: 1  # Request mock GPU
          limits:
            cpu: 500m
            memory: 256Mi
            nvidia.com/gpu: 1
```

## Implementation Steps

### 1. Create Mock GPU Node Configuration

```bash
# Create mock GPU node terraform config
cat > infrastructure/terraform/environments/local/mock-gpu-node.tf << 'EOF'
# Mock GPU node for macOS testing
resource "kind_cluster" "data_platform" {
  # ... existing config ...
  
  node {
    role = "worker"
    
    kubeadm_config_patches = [
      <<-EOT
      kind: JoinConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "nvidia.com/gpu.present=true,gpu-simulation=enabled,node-role=gpu-worker"
      EOT
    ]
  }
}
EOF
```

### 2. Deploy Mock GPU Device Plugin

```yaml
# infrastructure/kubernetes/gpu-simulation/mock-device-plugin.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mock-gpu-script
  namespace: kube-system
data:
  mock-gpu.sh: |
    #!/bin/bash
    set -e
    
    echo "Starting Mock GPU Device Plugin"
    
    # Create device plugin directory
    mkdir -p /var/lib/kubelet/device-plugins
    
    # Create mock GPU devices
    for i in {0..1}; do
        echo "Creating mock GPU device: nvidia$i"
        echo "mock-gpu-$i" > /tmp/gpu-$i
    done
    
    # Register with kubelet (simplified mock)
    echo "Registering 2 mock GPUs with kubelet"
    
    # Keep running
    while true; do
        echo "Mock GPU heartbeat at $(date)"
        sleep 30
    done

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: mock-gpu-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: mock-gpu-device-plugin
  template:
    metadata:
      labels:
        name: mock-gpu-device-plugin
    spec:
      hostNetwork: true
      containers:
      - name: mock-gpu-plugin
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/mock-gpu.sh"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: scripts
        configMap:
          name: mock-gpu-script
          defaultMode: 0755
      nodeSelector:
        gpu-simulation: "enabled"
      tolerations:
      - operator: Exists
```

### 3. Manual Node Resource Patching

```bash
# Patch worker node to advertise GPU resources
kubectl patch node data-platform-local-worker --type='merge' -p='
{
  "metadata": {
    "labels": {
      "nvidia.com/gpu.present": "true",
      "gpu-simulation": "enabled"
    }
  },
  "status": {
    "capacity": {
      "nvidia.com/gpu": "2"
    },
    "allocatable": {
      "nvidia.com/gpu": "2"
    }
  }
}'
```

### 4. ArgoCD Integration

```yaml
# Update gpu-nodes application for simulation
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gpu-simulation
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/infrastructure
    path: infrastructure/kubernetes/gpu-simulation
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Testing GPU Simulation

### 1. Deploy Test Workload

```bash
# Create test GPU workload
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpu-test
  template:
    metadata:
      labels:
        app: gpu-test
    spec:
      containers:
      - name: gpu-simulator
        image: nvidia/cuda:11.8-base-ubuntu20.04
        command: ["nvidia-smi"]  # This will fail gracefully on mock
        resources:
          limits:
            nvidia.com/gpu: 1
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: nvidia.com/gpu.present
              operator: In
              values: ["true"]
EOF
```

### 2. Verify Scheduling

```bash
# Check if pod scheduled on GPU node
kubectl get pods -o wide

# Check node resources
kubectl describe node data-platform-local-worker | grep nvidia.com/gpu

# Check GPU allocation
kubectl get pods gpu-test -o yaml | grep nvidia.com/gpu
```

## Limitations on macOS

### ❌ **Cannot Simulate:**

- Actual CUDA operations
- GPU memory management
- Hardware-specific features
- Real GPU metrics (nvidia-smi)

### ✅ **Can Simulate:**

- Kubernetes GPU scheduling
- Node affinity and tolerations
- Resource requests and limits
- Pod placement on GPU nodes
- ArgoCD GPU app management

## Real GPU Testing Alternatives

### 1. **Cloud GPU Instances**

```bash
# Use cloud providers for real GPU testing
# AWS p3.2xlarge, GCP n1-standard-4 with GPU
# Deploy same ArgoCD configs to cloud cluster
```

### 2. **Remote GPU Clusters**

```bash
# Connect to remote GPU cluster
kubectl config use-context remote-gpu-cluster
# Deploy workloads remotely while developing locally
```

### 3. **Docker Desktop with WSL2** (if using Parallels)

```bash
# WSL2 supports GPU passthrough
# Can run real NVIDIA container toolkit
```

## Development Workflow

### 1. **Local Development** (macOS + Mock)

- Test Kubernetes configurations
- Validate ArgoCD applications
- Debug scheduling logic

### 2. **GPU Validation** (Cloud/Remote)

- Deploy same configs to real GPU cluster
- Validate actual GPU workloads
- Performance testing

### 3. **Production Deployment**

- Use validated configurations
- Real GPU hardware
- Full monitoring stack

## Mock GPU Monitoring

```yaml
# Mock GPU metrics for Prometheus
apiVersion: v1
kind: ConfigMap
metadata:
  name: mock-gpu-metrics
data:
  metrics.txt: |
    # HELP nvidia_gpu_utilization_percent GPU utilization
    # TYPE nvidia_gpu_utilization_percent gauge
    nvidia_gpu_utilization_percent{gpu="0",uuid="mock-gpu-0"} 75.0
    nvidia_gpu_utilization_percent{gpu="1",uuid="mock-gpu-1"} 60.0
    
    # HELP nvidia_gpu_memory_used_bytes GPU memory used
    # TYPE nvidia_gpu_memory_used_bytes gauge
    nvidia_gpu_memory_used_bytes{gpu="0",uuid="mock-gpu-0"} 4294967296
    nvidia_gpu_memory_used_bytes{gpu="1",uuid="mock-gpu-1"} 2147483648
```

**Recommendation**: Use mock GPU simulation for Kubernetes scheduling development, then validate on real GPU
infrastructure for production workloads.
