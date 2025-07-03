#!/bin/bash
set -euo pipefail

# Certificate generation script for ML Platform
# Supports both local development and production environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"
ENVIRONMENT="${1:-local}"

# Configuration
case "$ENVIRONMENT" in
    "local"|"kind")
        DOMAIN="ml-platform.local"
        SANS="DNS:ml-platform.local,DNS:api.ml-platform.local,DNS:minio.ml-platform.local,DNS:localhost,IP:127.0.0.1"
        DAYS=365
        ;;
    "dev"|"staging"|"prod")
        DOMAIN="ml-platform.example.com"  # Update with your actual domain
        SANS="DNS:ml-platform.example.com,DNS:api.ml-platform.example.com,DNS:minio.ml-platform.example.com"
        DAYS=90
        ;;
    *)
        echo "Usage: $0 [local|dev|staging|prod]"
        echo "Environment '$ENVIRONMENT' not supported"
        exit 1
        ;;
esac

echo "Generating certificates for environment: $ENVIRONMENT"
echo "Domain: $DOMAIN"
echo "Valid for: $DAYS days"

# Create certificates directory
mkdir -p "$CERTS_DIR"

# Generate CA private key
if [[ ! -f "$CERTS_DIR/ca.key" ]]; then
    echo "Generating CA private key..."
    openssl genrsa -out "$CERTS_DIR/ca.key" 4096
fi

# Generate CA certificate
if [[ ! -f "$CERTS_DIR/ca.crt" ]]; then
    echo "Generating CA certificate..."
    openssl req -new -x509 -key "$CERTS_DIR/ca.key" -sha256 -subj "/CN=ML Platform CA" -days $DAYS -out "$CERTS_DIR/ca.crt"
fi

# Generate server private key
echo "Generating server private key..."
openssl genrsa -out "$CERTS_DIR/tls.key" 4096

# Generate certificate signing request
echo "Generating certificate signing request..."
openssl req -new -key "$CERTS_DIR/tls.key" -out "$CERTS_DIR/server.csr" -subj "/CN=$DOMAIN"

# Create extensions file for SAN
cat > "$CERTS_DIR/server.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
subjectAltName=$SANS
EOF

# Generate server certificate
echo "Generating server certificate..."
openssl x509 -req -in "$CERTS_DIR/server.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAcreateserial -out "$CERTS_DIR/tls.crt" -days $DAYS -sha256 -extfile "$CERTS_DIR/server.ext"

# Clean up temporary files
rm "$CERTS_DIR/server.csr" "$CERTS_DIR/server.ext"

# Generate Kubernetes TLS secret YAML
echo "Generating Kubernetes TLS secret..."
cat > "$CERTS_DIR/ml-platform-tls-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ml-platform-tls
  namespace: ml-platform
  labels:
    app.kubernetes.io/name: ml-platform-tls
    app.kubernetes.io/component: security
    environment: $ENVIRONMENT
type: kubernetes.io/tls
data:
  tls.crt: $(base64 -w 0 < "$CERTS_DIR/tls.crt")
  tls.key: $(base64 -w 0 < "$CERTS_DIR/tls.key")
EOF

echo "Certificate generation complete!"
echo "Files generated in: $CERTS_DIR"
echo "  - ca.crt (CA certificate)"
echo "  - ca.key (CA private key)"
echo "  - tls.crt (Server certificate)"
echo "  - tls.key (Server private key)"
echo "  - ml-platform-tls-secret.yaml (Kubernetes secret)"

if [[ "$ENVIRONMENT" == "local" || "$ENVIRONMENT" == "kind" ]]; then
    echo ""
    echo "For local development, add the following to your /etc/hosts:"
    echo "127.0.0.1 ml-platform.local api.ml-platform.local minio.ml-platform.local"
    echo ""
    echo "To trust the CA certificate, run:"
    echo "  sudo cp $CERTS_DIR/ca.crt /usr/local/share/ca-certificates/ml-platform-ca.crt"
    echo "  sudo update-ca-certificates"
fi