#!/bin/bash
set -euo pipefail

# Fix Terraform State Issues
# Handles namespace conflicts and resource dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform/environments/local"

cd "$TERRAFORM_DIR"

echo "🔧 Fixing Terraform state issues..."

# Skip if this is a fresh deployment (no existing state)
if [ ! -f "terraform.tfstate" ] || [ ! -s "terraform.tfstate" ]; then
    echo "ℹ️  Fresh deployment detected - skipping state fixes"
    exit 0
fi

# 1. Import existing namespaces if they exist
echo "📦 Checking for existing namespaces..."

for namespace in "app-core-team" "app-data-team" "app-ml-team" "data-platform-monitoring" "data-platform-performance" "data-platform-security"; do
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "✅ Found existing namespace: $namespace"

        # Try to import it to state if not already present
        if ! terraform state show "module.data_platform.kubernetes_namespace.team_namespaces[\"${namespace#app-}\"]" >/dev/null 2>&1 && [[ "$namespace" =~ ^app- ]]; then
            team_name="${namespace#app-}"
            echo "📥 Importing team namespace: $namespace as $team_name"
            terraform import "module.data_platform.kubernetes_namespace.team_namespaces[\"$team_name\"]" "$namespace" || echo "⚠️  Import failed for $namespace"
        fi

        # Import performance monitoring namespace
        if [[ "$namespace" == "data-platform-performance" ]]; then
            echo "📥 Importing performance monitoring namespace"
            terraform import "module.data_platform.module.performance_monitoring[0].module.kubernetes_performance_monitoring[0].kubernetes_namespace.performance_monitoring" "$namespace" || echo "⚠️  Import failed for performance monitoring namespace"
        fi

        # Import monitoring namespace
        if [[ "$namespace" == "data-platform-monitoring" ]]; then
            echo "📥 Importing monitoring namespace"
            terraform import "module.data_platform.module.monitoring[0].module.kubernetes_monitoring[0].kubernetes_namespace.monitoring" "$namespace" || echo "⚠️  Import failed for monitoring namespace"
        fi
    else
        echo "ℹ️  Namespace will be created: $namespace"
    fi
done

# 2. Remove conflicting label resources from state
echo "🏷️  Handling label conflicts..."
for team in "core-team" "data-team" "ml-team"; do
    resource_name="module.data_platform.module.security[0].module.kubernetes_security.kubernetes_labels.namespace_security"

    # Find the index for this team namespace
    for index in 0 1 2; do
        if terraform state show "${resource_name}[${index}]" 2>/dev/null | grep -q "app-${team}"; then
            echo "🗑️  Removing conflicting label resource for app-${team}"
            terraform state rm "${resource_name}[${index}]" || echo "⚠️  Failed to remove label resource"
            break
        fi
    done
done

# 3. Clean up orphaned resources
echo "🧹 Cleaning up orphaned resources..."

# Remove any resources that reference deleted namespaces
orphaned_resources=(
    "module.data_platform.module.performance_monitoring[0].module.kubernetes_performance_monitoring[0].kubernetes_service_account.fluent_bit[0]"
    "module.data_platform.module.performance_monitoring[0].module.kubernetes_performance_monitoring[0].kubernetes_service_account.otel_collector[0]"
    "module.data_platform.module.performance_monitoring[0].module.kubernetes_performance_monitoring[0].kubernetes_service.elasticsearch[0]"
    "module.data_platform.module.performance_monitoring[0].module.kubernetes_performance_monitoring[0].kubernetes_service.kibana[0]"
)

for resource in "${orphaned_resources[@]}"; do
    if terraform state show "$resource" >/dev/null 2>&1; then
        echo "🗑️  Removing orphaned resource: $resource"
        terraform state rm "$resource" || echo "⚠️  Failed to remove $resource"
    fi
done

# 4. Validate the plan
echo "✅ Validating Terraform configuration..."
terraform validate

echo "📋 Generating plan to check for remaining issues..."
terraform plan -detailed-exitcode -out=tfplan.tmp || {
    exit_code=$?
    if [ $exit_code -eq 2 ]; then
        echo "📝 Changes detected in plan (this is expected)"
    else
        echo "❌ Plan failed with exit code: $exit_code"
        exit $exit_code
    fi
}

rm -f tfplan.tmp

echo "✅ Terraform state fixes completed!"
echo ""
echo "Next steps:"
echo "1. Run 'make init-tf-local && make apply-tf-local' to apply the fixes"
echo "2. If you still encounter issues, run 'kubectl get namespaces' to verify namespace state"
echo "3. Check 'terraform state list' to verify resource state"
