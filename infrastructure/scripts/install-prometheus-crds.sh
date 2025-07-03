#!/bin/bash
# Install Prometheus Operator CRDs
# This script should be run during cluster bootstrap

set -e

echo "Installing Prometheus Operator CRDs..."

# Base URL for Prometheus Operator CRDs
BASE_URL="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd"

# List of required CRDs
CRDS=(
    "monitoring.coreos.com_servicemonitors.yaml"
    "monitoring.coreos.com_podmonitors.yaml"
    "monitoring.coreos.com_prometheusrules.yaml"
    "monitoring.coreos.com_prometheuses.yaml"
    "monitoring.coreos.com_alertmanagers.yaml"
)

# Install each CRD
for crd in "${CRDS[@]}"; do
    echo "Installing CRD: $crd"
    if ! kubectl apply -f "${BASE_URL}/${crd}"; then
        echo "Warning: Failed to install $crd - may already exist or be unavailable"
    fi
done

echo "Verifying CRD installation..."
kubectl get crd | grep monitoring.coreos.com || echo "No monitoring CRDs found"

echo "Prometheus Operator CRDs installation complete!"