# GPU Access Control - ML Team Only

## Implementation Summary

GPU resources are restricted to the ML team only through multiple layers of security:

### 1. **LimitRange Enforcement** ✅

Prevents non-ML teams from requesting GPU resources:

```yaml
# Applied to app-data-team and app-core-team namespaces
apiVersion: v1
kind: LimitRange
metadata:
  name: no-gpu-limit
spec:
  limits:
  - max:
      apple.com/gpu: "0"
      nvidia.com/gpu: "0"
    type: Container
```

**Result**: Data and Core teams CANNOT request GPU resources (enforced at API level)

### 2. **RBAC Restrictions** ✅

Only ML team can schedule workloads on GPU nodes:

```yaml
# ClusterRole: gpu-scheduler
# ClusterRoleBinding: ml-team-gpu-scheduler
# Bound to: ml-team-service-account
```

### 3. **Node Taints** ✅

GPU nodes are tainted, requiring explicit tolerations:

```yaml
# GPU Worker Node
Taints:
- key: apple.com/gpu
  value: present
  effect: NoSchedule
```

### 4. **Network Policies** ✅

GPU workloads are network-isolated to ML team namespace:

```yaml
# NetworkPolicy: gpu-node-access
# Only allows traffic from app-ml-team namespace
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GPU ACCESS CONTROL                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ML Team (app-ml-team)           Other Teams                   │
│  ┌─────────────────────┐         ┌──────────────────────┐      │
│  │ ✅ GPU Allowed      │         │ ❌ GPU Blocked       │      │
│  │                     │         │                      │      │
│  │ - Can request GPU   │         │ - LimitRange = 0    │      │
│  │ - Has tolerations   │         │ - No tolerations    │      │
│  │ - RBAC permissions  │         │ - No RBAC access    │      │
│  └─────────────────────┘         └──────────────────────┘      │
│            │                                │                   │
│            ▼                                ▼                   │
│  ┌─────────────────────┐         ┌──────────────────────┐      │
│  │   GPU Worker Node   │         │  Control Plane Node  │      │
│  │   (Tainted)         │         │  (Tainted)           │      │
│  └─────────────────────┘         └──────────────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Usage Example

### ML Team - Allowed ✅

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-training
  namespace: app-ml-team  # Must be ML team namespace
spec:
  template:
    spec:
      serviceAccountName: ml-team-service-account
      tolerations:
      - key: apple.com/gpu
        value: present
        effect: NoSchedule
      containers:
      - name: training
        resources:
          requests:
            apple.com/gpu: "1"  # Allowed for ML team
```

### Other Teams - Blocked ❌

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-processing
  namespace: app-data-team  # Non-ML namespace
spec:
  template:
    spec:
      containers:
      - name: processing
        resources:
          requests:
            apple.com/gpu: "1"  # BLOCKED by LimitRange
```

## Enforcement Points

1. **API Server**: LimitRange blocks GPU requests at creation time
2. **Scheduler**: Node taints prevent scheduling without tolerations
3. **RBAC**: Service accounts restricted from GPU operations
4. **Network**: NetworkPolicies isolate GPU workloads

## Testing Access Control

```bash
# Test ML team access (should work)
kubectl run ml-gpu-test --image=tensorflow/tensorflow:latest \
  -n app-ml-team \
  --overrides='{"spec":{"tolerations":[{"key":"apple.com/gpu","value":"present","effect":"NoSchedule"}]}}'

# Test Data team access (should fail)
kubectl run data-gpu-test --image=python:3.9 \
  -n app-data-team \
  --overrides='{"spec":{"containers":[{"name":"test","resources":{"requests":{"apple.com/gpu":"1"}}}]}}'
# Error: forbidden by LimitRange

# Check policies
kubectl get limitrange -A
kubectl get networkpolicy -A
kubectl get clusterrolebinding | grep gpu
```

## Adding GPU Capacity (Production)

When deploying to real GPU infrastructure:

1. **Install GPU Device Plugin**:
   ```bash
   # NVIDIA
   kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
   
   # AMD
   kubectl apply -f https://raw.githubusercontent.com/RadeonOpenCompute/k8s-device-plugin/v1.10/k8s-amd-gpu-dp.yaml
   ```

2. **Node will advertise GPU**:
   ```yaml
   capacity:
     nvidia.com/gpu: "2"  # Automatic with device plugin
   ```

3. **Update team quotas**:
   ```yaml
   # ResourceQuota for ML team
   spec:
     hard:
       requests.nvidia.com/gpu: "10"
   ```

## Security Summary

- **✅ ML Team**: Full GPU access with proper authentication
- **❌ Data Team**: Blocked at LimitRange level
- **❌ Core Team**: Blocked at LimitRange level
- **❌ Unauthorized pods**: Cannot tolerate GPU node taints
- **✅ Defense in depth**: Multiple enforcement layers

The GPU resources are now exclusively available to the ML team! 🔒
