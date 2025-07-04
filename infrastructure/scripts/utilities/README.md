# Utility Scripts

Helper scripts for setup, maintenance, labeling, and status checking.

## Setup & Prerequisites

- **`terraform-provider-kind-setup.sh`** - Build and install custom Kind Terraform provider
- **`build-docker-with-provider.sh`** - Build Docker image with Terraform provider included

## Operations

- **`view-federation.sh`** - Check cluster status and federation information

## Usage

### Prerequisites Setup

```bash
# Install custom Kind provider (required for local development)
./terraform-provider-kind-setup.sh

# Build containerized environment with all tools
./build-docker-with-provider.sh
```

### Cluster Status

```bash
./view-federation.sh
```

Shows cluster information, useful for debugging network policies and team isolation.

These utilities help with setup and operational tasks. Resource labeling should be handled declaratively through
Terraform and Kubernetes manifests, not manual scripts.
