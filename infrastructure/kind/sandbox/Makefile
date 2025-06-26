# ==============================================================================
# Kind Cluster Management for ML Platform
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration Variables
# ------------------------------------------------------------------------------

# Cluster Configuration
CLUSTER_NAME ?= ml-platform-sandbox
CONFIG_FILE := kind-sandbox-shared-config.yaml
CONFIG_TEMPLATE := kind-sandbox-config.yaml.tmpl

# Kubernetes Configuration  
K8S_VERSION ?= 1.30.0
POD_SUBNET ?= 10.244.0.0/16
SERVICE_SUBNET ?= 10.96.0.0/12

# Registry Configuration
REGISTRY_NAME ?= kind-registry
REGISTRY_PORT ?= 5000

# Application Namespaces
NAMESPACES ?= ml-platform monitoring logging

# Directory Configuration
DATA_DIR ?= ./data
LOGS_DIR ?= ./logs

# Resource Limits Configuration
CONTROL_PLANE_SYSTEM_RESERVED ?= cpu=200m,memory=500Mi
CONTROL_PLANE_KUBE_RESERVED ?= cpu=200m,memory=500Mi
ML_NODE_SYSTEM_RESERVED ?= cpu=500m,memory=1Gi
ML_NODE_KUBE_RESERVED ?= cpu=500m,memory=1Gi
WORKER_NODE_SYSTEM_RESERVED ?= cpu=200m,memory=500Mi
WORKER_NODE_KUBE_RESERVED ?= cpu=200m,memory=500Mi

# Audit Log Configuration
AUDIT_LOG_MAXAGE ?= 7
AUDIT_LOG_MAXBACKUP ?= 3
AUDIT_LOG_MAXSIZE ?= 100

# External Component URLs
NGINX_INGRESS_URL := https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
LOCAL_PATH_PROVISIONER_URL := https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
METRICS_SERVER_URL := https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Export variables for envsubst template processing
export CLUSTER_NAME K8S_VERSION POD_SUBNET SERVICE_SUBNET REGISTRY_NAME REGISTRY_PORT
export DATA_DIR LOGS_DIR
export CONTROL_PLANE_SYSTEM_RESERVED CONTROL_PLANE_KUBE_RESERVED
export ML_NODE_SYSTEM_RESERVED ML_NODE_KUBE_RESERVED
export WORKER_NODE_SYSTEM_RESERVED WORKER_NODE_KUBE_RESERVED
export AUDIT_LOG_MAXAGE AUDIT_LOG_MAXBACKUP AUDIT_LOG_MAXSIZE

# ------------------------------------------------------------------------------
# Main Targets
# ------------------------------------------------------------------------------

.PHONY: help
help: ## Show this help message
	@echo "Kind Cluster Management for ML Platform"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Main Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'

.PHONY: setup-cluster
setup-cluster: check-prerequisites create-directories create-cluster wait-for-cluster install-ingress install-storage install-metrics-server-dev create-namespaces create-registry label-nodes show-cluster-info ## Complete cluster setup (development mode)

.PHONY: setup-cluster-prod
setup-cluster-prod: check-prerequisites create-directories create-cluster wait-for-cluster install-ingress install-storage install-metrics-server-prod create-namespaces create-registry label-nodes show-cluster-info ## Complete cluster setup (production mode)

.PHONY: destroy-all
destroy-all: clean-cluster clean-registry clean-directories ## Delete cluster and all associated resources

# ------------------------------------------------------------------------------
# Cluster Management
# ------------------------------------------------------------------------------

.PHONY: create-cluster
create-cluster: generate-config ## Create Kind cluster
	@echo "Creating Kind cluster named $(CLUSTER_NAME)..."
	@kind create cluster --name $(CLUSTER_NAME) --config $(CONFIG_FILE)

.PHONY: clean-cluster
clean-cluster: ## Delete the Kind cluster
	@echo "Deleting Kind cluster named $(CLUSTER_NAME)..."
	@kind delete cluster --name $(CLUSTER_NAME)

.PHONY: clean-clusters
clean-clusters: ## Delete all Kind clusters
	@echo "Deleting all Kind clusters..."
	@kind get clusters | xargs -n 1 kind delete cluster --name

.PHONY: list-clusters
list-clusters: ## List all Kind clusters
	@echo "Listing all Kind clusters..."
	@kind get clusters

.PHONY: generate-config
generate-config: ## Generate Kind configuration from template
	@echo "Generating Kind config from template..."
	@envsubst < $(CONFIG_TEMPLATE) > $(CONFIG_FILE)

.PHONY: wait-for-cluster
wait-for-cluster: ## Wait for cluster nodes to be ready
	@echo "Waiting for cluster nodes to be ready..."
	@kubectl wait --for=condition=Ready nodes --all --timeout=120s

# ------------------------------------------------------------------------------
# Component Installation
# ------------------------------------------------------------------------------

.PHONY: install-ingress
install-ingress: ## Install NGINX Ingress Controller
	@echo "Installing NGINX Ingress Controller..."
	@kubectl apply -f $(NGINX_INGRESS_URL)
	@echo "Waiting for ingress controller to be ready..."
	@kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s

.PHONY: install-storage
install-storage: ## Install local-path storage provisioner
	@echo "Installing local-path storage provisioner..."
	@kubectl apply -f $(LOCAL_PATH_PROVISIONER_URL)

.PHONY: install-metrics-server
install-metrics-server: install-metrics-server-dev ## Install metrics-server (development mode)

.PHONY: install-metrics-server-dev
install-metrics-server-dev: ## Install metrics-server with insecure TLS (development)
	@echo "Installing metrics-server (development mode - insecure TLS)..."
	@kubectl apply -f metrics-server-dev.yaml

.PHONY: install-metrics-server-prod
install-metrics-server-prod: ## Install metrics-server with secure TLS (production)
	@echo "Installing metrics-server (production mode - secure TLS)..."
	@if [ ! -f "certs/metrics-server.crt" ]; then \
		echo "Generating TLS certificates..."; \
		./generate-metrics-certs.sh; \
	fi
	@kubectl apply -f certs/metrics-server-secret.yaml
	@kubectl apply -f metrics-server-prod.yaml

.PHONY: create-namespaces
create-namespaces: ## Create application namespaces
	@echo "Creating namespaces..."
	@for ns in $(NAMESPACES); do \
		kubectl create namespace $$ns --dry-run=client -o yaml | kubectl apply -f -; \
	done

.PHONY: label-nodes
label-nodes: ## Label worker nodes with their types
	@echo "Labeling nodes..."
	@kubectl get nodes -o name | grep worker | head -1 | xargs -I {} kubectl label {} node-type=compute --overwrite || true
	@kubectl get nodes -o name | grep worker | sed -n '2p' | xargs -I {} kubectl label {} node-type=ml --overwrite || true
	@kubectl get nodes -o name | grep worker | sed -n '3p' | xargs -I {} kubectl label {} node-type=storage --overwrite || true

# ------------------------------------------------------------------------------
# Registry Management
# ------------------------------------------------------------------------------

.PHONY: create-registry
create-registry: ## Create secure Docker registry with TLS and authentication
	@echo "Creating local Docker registry with TLS and authentication..."
	@if [ ! -f "./setup-registry.sh" ]; then \
		echo "Error: setup-registry.sh not found"; \
		exit 1; \
	fi
	@./setup-registry.sh
	@echo "Connecting registry to kind network..."
	@docker network connect "kind" registry_registry_1 2>/dev/null || \
	 docker network connect "kind" $(REGISTRY_NAME) 2>/dev/null || true

.PHONY: setup-simple-registry
setup-simple-registry: ## Create simple Docker registry without TLS
	@echo "Creating simple Docker registry (no TLS)..."
	@docker run -d --restart=always -p $(REGISTRY_PORT):5000 --name $(REGISTRY_NAME) registry:2 || true
	@echo "Connecting registry to kind network..."
	@docker network connect "kind" $(REGISTRY_NAME) || true

.PHONY: registry-login
registry-login: ## Login to the local registry
	@echo "Logging into local registry..."
	@docker login localhost:25000 -u ${REGISTRY_USERNAME:-admin} -p ${REGISTRY_PASSWORD:-password}

.PHONY: registry-status
registry-status: ## Check registry status
	@echo "Registry status:"
	@docker compose -f docker-compose.yml ps || echo "Docker Compose not running"
	@curl -k -s https://localhost:25000/v2/ && echo "✓ Registry is accessible" || echo "✗ Registry not accessible"

.PHONY: clean-registry
clean-registry: ## Remove local registry and data
	@echo "Removing local registry..."
	@docker compose -f docker-compose.yml down || true
	@docker rm -f $(REGISTRY_NAME) || true
	@rm -rf auth certs registry-data

# ------------------------------------------------------------------------------
# Certificate Management
# ------------------------------------------------------------------------------

.PHONY: generate-metrics-certs
generate-metrics-certs: ## Generate TLS certificates for metrics-server
	@echo "Generating TLS certificates for metrics-server..."
	@./generate-metrics-certs.sh

# ------------------------------------------------------------------------------
# Utility Targets
# ------------------------------------------------------------------------------

.PHONY: check-prerequisites
check-prerequisites: ## Check if required tools are installed
	@echo "Checking prerequisites..."
	@command -v kind >/dev/null 2>&1 || { echo "Error: kind is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed"; exit 1; }
	@echo "All prerequisites installed ✓"

.PHONY: create-directories
create-directories: ## Create necessary directories for volume mounts
	@echo "Creating directories for volume mounts..."
	@mkdir -p $(DATA_DIR) $(LOGS_DIR)

.PHONY: clean-directories
clean-directories: ## Remove created directories
	@echo "Removing directories..."
	@rm -rf $(DATA_DIR) $(LOGS_DIR)

.PHONY: show-cluster-info
show-cluster-info: ## Display cluster information
	@echo ""
	@echo "✓ Kind cluster setup complete!"
	@echo ""
	@echo "Cluster Info:"
	@echo "- Name: $(CLUSTER_NAME)"
	@echo "- API Server: https://localhost:6443"
	@echo "- Ingress: http://localhost (HTTP) / https://localhost (HTTPS)"
	@echo "- Local Registry: localhost:25000"
	@echo ""
	@echo "Namespaces created: $(NAMESPACES)"
	@echo ""
	@echo "To use the cluster:"
	@echo "  kubectl config use-context kind-$(CLUSTER_NAME)"
	@echo ""
	@echo "To delete the cluster:"
	@echo "  make clean-cluster"

.PHONY: cluster-status
cluster-status: ## Show cluster status and health
	@echo "Cluster Status:"
	@kubectl cluster-info || echo "Cluster not accessible"
	@echo ""
	@echo "Node Status:"
	@kubectl get nodes || echo "Nodes not accessible"
	@echo ""
	@echo "Namespace Status:"
	@kubectl get namespaces || echo "Namespaces not accessible"

# ------------------------------------------------------------------------------
# Development Helpers
# ------------------------------------------------------------------------------

.PHONY: load-image
load-image: ## Load a Docker image into the cluster (requires DOCKER_IMAGE variable)
	@if [ -z "$(DOCKER_IMAGE)" ]; then \
		echo "Error: DOCKER_IMAGE variable is required"; \
		echo "Usage: make load-image DOCKER_IMAGE=myapp:latest"; \
		exit 1; \
	fi
	@echo "Loading Docker image $(DOCKER_IMAGE) into Kind cluster $(CLUSTER_NAME)..."
	@kind load docker-image $(DOCKER_IMAGE) --name $(CLUSTER_NAME)

.PHONY: debug-config
debug-config: ## Show current configuration values
	@echo "Current Configuration:"
	@echo "- CLUSTER_NAME: $(CLUSTER_NAME)"
	@echo "- K8S_VERSION: $(K8S_VERSION)"
	@echo "- REGISTRY_PORT: $(REGISTRY_PORT)"
	@echo "- NAMESPACES: $(NAMESPACES)"
	@echo "- DATA_DIR: $(DATA_DIR)"
	@echo "- LOGS_DIR: $(LOGS_DIR)"

# ------------------------------------------------------------------------------
# Default Target
# ------------------------------------------------------------------------------

.DEFAULT_GOAL := help