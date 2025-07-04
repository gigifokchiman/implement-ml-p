# Management Scripts

Scripts for managing individual clusters and platform components.

## Scripts

- **`create-app-cluster.sh`** - Create individual application clusters using Terraform templates

## Usage

```bash
./create-app-cluster.sh <app-name> [http-port] [https-port]
```

## What It Does

- Creates Terraform environment for the application
- Sets up Kind cluster with proper networking
- Configures database, cache, and storage services
- Provides port forwarding instructions

## Examples

```bash
./create-app-cluster.sh analytics-platform 8110 8463
./create-app-cluster.sh user-service 8120 8473
```

This is used internally by `deploy-new-app.sh` but can be run standalone for custom setups.