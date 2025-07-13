# High Availability Control Plane Guide

## Overview

This guide explains the differences between single and multiple control plane replicas, and how to implement HA control
plane for your data platform.

## Single vs HA Control Plane

### Single Control Plane

```
┌─────────────────────────┐
│   Control Plane Node    │
├─────────────────────────┤
│ • API Server            │
│ • etcd                  │
│ • Controller Manager    │
│ • Scheduler             │
│ • Single Point of Failure│
└─────────────────────────┘
```

### HA Control Plane (3 nodes)

```
┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐
│   Control Plane 1       │     │   Control Plane 2       │     │   Control Plane 3       │
├─────────────────────────┤     ├─────────────────────────┤     ├─────────────────────────┤
│ • API Server            │◄────┤ • API Server            │────►│ • API Server            │
│ • etcd (leader)         │     │ • etcd (follower)       │     │ • etcd (follower)       │
│ • Controller Manager    │     │ • Controller Manager    │     │ • Controller Manager    │
│ • Scheduler             │     │ • Scheduler             │     │ • Scheduler             │
│ • Load Balancer         │     │ • Load Balancer         │     │ • Load Balancer         │
└─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘
```

## Key Differences

### 1. Availability

- **Single**: Cluster unavailable if control plane fails
- **HA**: Cluster survives 1 control plane failure (with 3 nodes)

### 2. Resource Usage

- **Single**: ~2 CPU, 4GB RAM
- **HA**: ~6 CPU, 12GB RAM (3x control plane nodes)

### 3. Complexity

- **Single**: Simple setup, no leader election
- **HA**: Complex setup, etcd cluster, leader election

### 4. Network Requirements

- **Single**: Direct API server access
- **HA**: Load balancer in front of API servers

### 5. etcd Configuration

- **Single**: Single etcd instance
- **HA**: etcd cluster with quorum (3 nodes)

### 6. Backup/Recovery

- **Single**: Single point backup
- **HA**: Distributed backup, automatic failover

## Implementation Differences

### Configuration Changes

#### Single Control Plane

```yaml
node {
  role = "control-plane"
  # Simple configuration
}
```

#### HA Control Plane

```yaml
# Load balancer configuration
networking {
  api_server_address = "127.0.0.1"
  api_server_port    = 6443
}

# Multiple control plane nodes
node {
  role = "control-plane"
  # First node - initializes cluster
}
node {
  role = "control-plane"
  # Additional nodes join cluster
}
node {
  role = "control-plane"
  # Third node for quorum
}
```

### etcd Clustering

```yaml
# HA etcd configuration
kind: ClusterConfiguration
etcd:
  local:
    serverCertSANs:
    - "localhost"
    - "127.0.0.1"
    peerCertSANs:
    - "localhost"
    - "127.0.0.1"
```

## Architecture Options

### Option A: 3 Control Plane + 2 Workers (5 nodes)

```
Control Plane 1 + Control Plane 2 + Control Plane 3 + Infrastructure Node + Workload Node
```

**Resources**: 3×2 + 4 + 8 = 18 CPU, 3×4 + 8 + 16 = 40GB RAM

### Option B: 3 Control Plane + 1 Worker (4 nodes)

```
Control Plane 1 + Control Plane 2 + Control Plane 3 + Combined Worker Node
```

**Resources**: 3×2 + 8 = 14 CPU, 3×4 + 16 = 28GB RAM

### Option C: Current Single Control Plane (2 nodes)

```
Control Plane + Worker Node
```

**Resources**: 2 + 8 = 10 CPU, 4 + 16 = 20GB RAM

## When to Use HA Control Plane

### Use HA Control Plane When:

- **Production environments**
- **Critical workloads** that can't tolerate downtime
- **Compliance requirements** for high availability
- **Multi-team environments** where control plane failure affects many users
- **Long-running processes** that can't be easily restarted

### Use Single Control Plane When:

- **Development/testing environments**
- **Resource-constrained environments**
- **Simple use cases** with acceptable downtime
- **Learning/experimentation** scenarios
- **Cost optimization** is priority

## Implementation Steps

### 1. For HA Control Plane

```bash
# Use HA configuration
cp infrastructure/terraform/environments/local/main-ha-control-plane.tf \
   infrastructure/terraform/environments/local/main.tf

# Apply changes
cd infrastructure/terraform/environments/local
terraform destroy -auto-approve
terraform apply -auto-approve
```

### 2. Verify HA Setup

```bash
# Check all control plane nodes
kubectl get nodes -l node-role.kubernetes.io/control-plane

# Check etcd cluster health
kubectl get pods -n kube-system | grep etcd

# Test API server failover
kubectl get pods --all-namespaces
```

### 3. Monitor HA Components

```bash
# Check etcd cluster status
kubectl exec -n kube-system etcd-data-platform-local-control-plane -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  endpoint health

# Check API server load balancer
kubectl get endpoints kubernetes
```

## Pros and Cons

### HA Control Plane

**Pros:**

- High availability
- Automatic failover
- Production-ready
- Compliance-friendly

**Cons:**

- Higher resource usage
- More complex setup
- Network complexity
- Harder to troubleshoot

### Single Control Plane

**Pros:**

- Simple setup
- Lower resource usage
- Easy to troubleshoot
- Good for development

**Cons:**

- Single point of failure
- Manual recovery needed
- Not production-ready
- Downtime during updates

## Recommendation for Your Use Case

Given your requirements:

- **GPU/ML workloads**: Consider availability needs
- **Development environment**: Single control plane likely sufficient
- **Resource optimization**: Single control plane saves ~8 CPU, 16GB RAM
- **Future production**: Design for HA from start

**Recommended approach**: Start with single control plane, design infrastructure to be HA-ready for production
migration.

## Migration Path

### From Single to HA

1. Export cluster state
2. Backup persistent data
3. Apply HA configuration
4. Restore data
5. Verify all services

### From HA to Single

1. Drain 2 control plane nodes
2. Update configuration
3. Apply single node config
4. Verify cluster health

## Best Practices

1. **Always use odd number** of control plane nodes (3, 5, 7)
2. **Monitor etcd health** regularly
3. **Backup etcd data** frequently
4. **Test failover scenarios** regularly
5. **Use external load balancer** in production
6. **Plan for rolling updates** of control plane components
