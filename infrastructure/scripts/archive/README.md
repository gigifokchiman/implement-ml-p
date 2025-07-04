# Archived Scripts

This directory contains advanced/experimental scripts that are not part of the main workflow documented in the New
Engineer Runbook.

## Multi-Cluster & Federation Scripts

These scripts are for advanced users who need to scale beyond single-cluster team isolation:

- **`setup-federation.sh`** - Set up multi-cluster federation (migration from single cluster)
- **`add-cluster-to-federation.sh`** - Add a new cluster to an existing federation
- **`deploy-federated-clusters.sh`** - Deploy multiple federated clusters
- **`setup-prometheus-clusters.sh`** - Set up Prometheus across multiple clusters

## Helm-Based Deployment Scripts

Alternative deployment approaches using Helm instead of Terraform+Kubernetes:

- **`helm-deploy-platform.sh`** - Deploy platform using Helm charts
- **`helm-manage.sh`** - Manage Helm-based deployments

## Cluster Management Utilities

Individual cluster management tools:

- **`create-external-cluster.sh`** - Create external/remote clusters
- **`manage-clusters.sh`** - General cluster lifecycle management
- **`new-cluster.sh`** - Create new individual clusters

## Cleanup & Testing Utilities

- **`cleanup-test-clusters.sh`** - Clean up test environments
- **`apply-proper-labeling.sh`** - DEPRECATED: Manual labeling script (use Terraform/K8s manifests instead)

## When to Use These Scripts

### Single Cluster (Recommended - 80% of use cases)

Use the main scripts in `../` for:

- Local development
- Small to medium teams (< 100 developers)
- Namespace isolation is sufficient
- Cost optimization is important

### Multi-Cluster (Advanced - 20% of use cases)

Use these archived scripts when you need:

- Hard compliance boundaries (SOX, GDPR)
- Different Kubernetes versions per team
- Complete network isolation
- Enterprise-scale (> 100 developers)
- Disaster recovery across regions

## Migration Path

1. **Start** with single cluster using main scripts
2. **Validate** team isolation meets your needs
3. **Migrate** to multi-cluster using these archived scripts if needed

The main workflow provides 80% of multi-cluster benefits with 20% of the complexity.

---

*These scripts are maintained but not part of the primary workflow. Use with caution and ensure you understand the
implications.*
