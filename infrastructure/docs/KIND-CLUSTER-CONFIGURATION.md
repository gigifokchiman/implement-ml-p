# Kind Cluster Configuration Guide

This document explains all configurations used in the Kind cluster setup for the ML Platform sandbox environment.

**Last Updated:** January 2025  
**Kind Provider:** gigifokchiman/kind (v0.1.0)  
**Repository:** https://github.com/gigifokchiman/implement-ml-p

## Overview

The Kind cluster configuration (`kind-sandbox-shared-config.yaml`) defines a multi-node Kubernetes cluster with specialized node types and comprehensive security settings.

## Kind vs Production Kubernetes Comparison

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                              KIND (Kubernetes IN Docker)                          │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐              │
│  │   Docker Host   │     │   Docker Host   │     │   Docker Host   │              │
│  │  ┌───────────┐  │     │  ┌───────────┐  │     │  ┌───────────┐  │              │
│  │  │  Docker   │  │     │  │  Docker   │  │     │  │  Docker   │  │              │
│  │  │ Container │  │     │  │ Container │  │     │  │ Container │  │              │
│  │  │┌─────────┐│  │     │  │┌─────────┐│  │     │  │┌─────────┐│  │              │
│  │  ││Control  ││  │     │  ││ Worker  ││  │     │  ││ Worker  ││  │              │
│  │  ││ Plane   ││  │     │  ││  Node   ││  │     │  ││  Node   ││  │              │
│  │  │└─────────┘│  │     │  │└─────────┘│  │     │  │└─────────┘│  │              │
│  │  └───────────┘  │     │  └───────────┘  │     │  └───────────┘  │              │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘              │
│                                                                                   │
│  Features:                                                                        │
│  • Nodes run as Docker containers                                                 │
│  • Single machine deployment                                                      │
│  • Port mappings via Docker                                                       │
│  • Volumes via Docker mounts                                                      │
│  • Fast cluster creation (~30s)                                                   │
│  • Perfect for development/testing                                                │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘

                                        VS

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           PRODUCTION KUBERNETES                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐                │
│  │  Physical/VM    │     │  Physical/VM    │     │  Physical/VM    │                │
│  │   Server #1     │     │   Server #2     │     │   Server #3     │                │
│  │  ┌───────────┐  │     │  ┌───────────┐  │     │  ┌───────────┐  │                │
│  │  │   Host    │  │     │  │   Host    │  │     │  │   Host    │  │                │
│  │  │    OS     │  │     │  │    OS     │  │     │  │    OS     │  │                │
│  │  │┌─────────┐│  │     │  │┌─────────┐│  │     │  │┌─────────┐│  │                │
│  │  ││Control  ││  │     │  ││ Worker  ││  │     │  ││ Worker  ││  │                │
│  │  ││ Plane   ││  │     │  ││  Node   ││  │     │  ││  Node   ││  │                │
│  │  │└─────────┘│  │     │  │└─────────┘│  │     │  │└─────────┘│  │                │
│  │  └───────────┘  │     │  └───────────┘  │     │  └───────────┘  │                │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘                │
│                                                                                     │
│  Features:                                                                          │
│  • Nodes on separate machines                                                       │
│  • Multi-machine deployment                                                         │
│  • Network load balancers                                                           │
│  • Persistent storage systems                                                       │
│  • High availability setup                                                          │
│  • Production workloads                                                             │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Differences

| Aspect | Kind | Production Kubernetes |
|--------|------|----------------------|
| **Nodes** | Docker containers | Physical servers or VMs |
| **Networking** | Docker networks + iptables | Real network infrastructure |
| **Storage** | Docker volumes | Distributed storage (NFS, Ceph, etc.) |
| **Port Access** | Docker port mapping | Load balancers, NodePort, Ingress |
| **Performance** | Limited by single machine | Distributed resources |
| **HA** | No real HA (single machine) | True high availability |
| **Use Case** | Development/Testing | Production workloads |
| **Setup Time** | ~30 seconds | Hours to days |
| **Cost** | Free (local resources) | Infrastructure costs |

### Configuration Mapping

| Kind Configuration | Production Equivalent |
|-------------------|----------------------|
| `extraPortMappings` | LoadBalancer services, Ingress controllers |
| `extraMounts` | PersistentVolumes, StorageClasses |
| `nodes[].role` | Real servers with kubeadm join |
| `containerdConfigPatches` | Container runtime config on each node |
| `networking.podSubnet` | CNI plugin configuration |

## Cluster Specification

### Basic Configuration
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ml-platform-local
```
- **kind**: Specifies this is a Kind cluster configuration
- **apiVersion**: Kind API version for configuration compatibility
- **name**: Cluster identifier (matches the name in terraform configuration)

## Node Configuration

### Control Plane Node

The control plane node manages the Kubernetes cluster and includes several important configurations:

#### Node Registration
```yaml
node-labels: "ingress-ready=true"
system-reserved: "cpu=200m,memory=500Mi"
kube-reserved: "cpu=200m,memory=500Mi"
```
- **ingress-ready**: Labels the node to handle ingress traffic
- **system-reserved**: Resources reserved for OS system daemons
- **kube-reserved**: Resources reserved for Kubernetes system components

#### API Server Configuration
```yaml
enable-bootstrap-token-auth: "true"
audit-log-maxage: "7"
audit-log-maxbackup: "3"
audit-log-maxsize: "100"
audit-log-path: "/var/log/kubernetes/audit.log"
```
- **enable-bootstrap-token-auth**: Enables token-based authentication for node bootstrapping
- **audit-log-maxage**: Retains audit logs for maximum 7 days
- **audit-log-maxbackup**: Keeps maximum 3 old audit log files
- **audit-log-maxsize**: Maximum 100MB per audit log file before rotation
- **audit-log-path**: Location where audit logs are stored

#### Controller Manager Configuration
```yaml
cluster-signing-cert-file: /etc/kubernetes/pki/ca.crt
cluster-signing-key-file: /etc/kubernetes/pki/ca.key
bind-address: "0.0.0.0"
```
- **cluster-signing-cert/key-file**: CA certificate and key for signing cluster certificates
- **bind-address**: Listens on all interfaces for metrics and health checks

#### Scheduler Configuration
```yaml
bind-address: "0.0.0.0"
```
- **bind-address**: Allows scheduler metrics to be accessed from any interface

#### Kubelet Configuration
```yaml
serverTLSBootstrap: true
rotateCertificates: true
cgroupDriver: systemd
containerRuntimeEndpoint: unix:///run/containerd/containerd.sock
```
- **serverTLSBootstrap**: Enables automatic TLS certificate bootstrapping
- **rotateCertificates**: Automatically rotates certificates before expiry
- **cgroupDriver**: Uses systemd for cgroup management (must match container runtime)
- **containerRuntimeEndpoint**: Socket path for containerd communication

### Worker Nodes

The cluster includes three types of worker nodes, each optimized for different workloads:

#### Compute Node
```yaml
labels:
  node-type: compute
system-reserved: "cpu=200m,memory=500Mi"
kube-reserved: "cpu=200m,memory=500Mi"
```
- Standard compute resources for general workloads

#### ML Node
```yaml
labels:
  node-type: ml
system-reserved: "cpu=500m,memory=1Gi"
kube-reserved: "cpu=500m,memory=1Gi"
```
- Higher resource reservations for machine learning workloads
- More CPU and memory reserved for system operations

#### Storage Node
```yaml
labels:
  node-type: storage
system-reserved: "cpu=200m,memory=500Mi"
kube-reserved: "cpu=200m,memory=500Mi"
```
- Optimized for storage operations
- Standard resource reservations

## Port Mappings

```yaml
extraPortMappings:
  - containerPort: 80, hostPort: 80        # Ingress HTTP
  - containerPort: 443, hostPort: 443      # Ingress HTTPS
```

These mappings expose cluster services to the host machine:
- **80/443**: Standard web traffic through ingress
- **8000**: Backend API service

## Volume Mounts

```yaml
extraMounts:
  - hostPath: ./logs
    containerPath: /var/log
```
- **./data**: Persistent data storage accessible from host
- **./logs**: Log files accessible for debugging and monitoring

## Networking Configuration

```yaml
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  disableDefaultCNI: false
  kubeProxyMode: "iptables"
```
- **apiServerAddress/Port**: API server endpoint for kubectl access
- **podSubnet**: IP range for pod networking
- **serviceSubnet**: IP range for Kubernetes services
- **disableDefaultCNI**: Uses Kind's default CNI (kindnet)
- **kubeProxyMode**: Uses iptables for service load balancing

## Container Registry Configuration

```yaml
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
        endpoint = ["http://kind-registry:5000"]
    [plugins."io.containerd.grpc.v1.cri".registry.configs]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."kind-registry:5000".tls]
        insecure_skip_verify = true
```

Configures a local Docker registry for faster image pulls:
- **Registry mirror**: Points localhost:5000 to internal kind-registry
- **TLS skip**: Allows insecure registry for local development

## Feature Gates

```yaml
featureGates:
  EphemeralContainers: true
  GracefulNodeShutdown: true
```
- **EphemeralContainers**: Enables debugging containers in running pods
- **GracefulNodeShutdown**: Ensures pods are properly terminated during node shutdown

## Terraform Integration

The Kind cluster is managed by Terraform using the custom provider:

### Provider Configuration

```hcl
terraform {
  required_providers {
    kind = {
      source  = "gigifokchiman/kind"
      version = "0.1.0"
    }
  }
}

resource "kind_cluster" "ml_platform" {
  name = "ml-platform-local"
  config = file("${path.module}/kind-config.yaml")
}
```

### Provider Installation

```bash
# Install the custom Kind provider
cd infrastructure
./scripts/install-terraform-provider-kind.sh

# Or download manually
./scripts/download-kind-provider.sh
```

## Usage

### Creating the Cluster

**Option 1: Using Deployment Script (Recommended)**

```bash
cd infrastructure
./scripts/deploy-local.sh
```

**Option 2: Using Terraform Directly**

```bash
cd infrastructure/terraform/environments/local
terraform init
terraform apply
```

**Option 3: Using Kind CLI Directly**
```bash
kind create cluster --config infrastructure/terraform/environments/local/kind-config.yaml
```

### Applying Configuration Changes
Configuration changes require cluster recreation:
```bash
# Using Terraform
cd infrastructure/terraform/environments/local
terraform destroy
terraform apply

# Or using Kind directly
kind delete cluster --name ml-platform-local
kind create cluster --config kind-config.yaml
```

### Accessing the Cluster

```bash
# Kubectl is automatically configured
kubectl get nodes

# Access services
kubectl port-forward svc/postgresql 5432:5432 -n ml-platform
kubectl port-forward svc/redis 6379:6379 -n ml-platform
kubectl port-forward svc/minio 9000:9000 -n ml-platform

# Access ArgoCD (if deployed)
echo "URL: http://argocd.ml-platform.local:30080"
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
```

### Important Notes

1. **Cluster Name**: The cluster is named `ml-platform-local` consistently across all configurations.

2. **Resource Reservations**: The reserved resources ensure system stability under load. Adjust based on your host machine capabilities.

3. **Security**: This configuration includes audit logging and TLS bootstrapping for production-like security in development.

4. **Persistence**: Data and logs are mounted from host directories. These are created automatically by the deployment
   scripts.

5. **Port Mappings**: The cluster exposes ports 8080 (HTTP) and 8443 (HTTPS) for ingress traffic.
