# clusters
CLUSTER_NAME ?= ml-platform-sandbox
CONFIG_FILE := kind-sandbox-shared-config.yaml
CONFIG_TEMPLATE := kind-sandbox-config.yaml.tmpl

# versions
K8S_VERSION ?= 1.30.0
POD_SUBNET ?= 10.244.0.0/16
SERVICE_SUBNET ?= 10.96.0.0/12

# registry
REGISTRY_NAME ?= kind-registry
REGISTRY_PORT ?= 5000

# namespaces
NAMESPACES ?= ml-platform monitoring logging

# directories
DATA_DIR ?= ./data
LOGS_DIR ?= ./logs

# resource limits
CONTROL_PLANE_SYSTEM_RESERVED ?= cpu=200m,memory=500Mi
CONTROL_PLANE_KUBE_RESERVED ?= cpu=200m,memory=500Mi
ML_NODE_SYSTEM_RESERVED ?= cpu=500m,memory=1Gi
ML_NODE_KUBE_RESERVED ?= cpu=500m,memory=1Gi
WORKER_NODE_SYSTEM_RESERVED ?= cpu=200m,memory=500Mi
WORKER_NODE_KUBE_RESERVED ?= cpu=200m,memory=500Mi

# audit log settings
AUDIT_LOG_MAXAGE ?= 7
AUDIT_LOG_MAXBACKUP ?= 3
AUDIT_LOG_MAXSIZE ?= 100

# URLs for external resources
NGINX_INGRESS_URL := https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
LOCAL_PATH_PROVISIONER_URL := https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
METRICS_SERVER_URL := https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Export variables for envsubst
export CLUSTER_NAME K8S_VERSION POD_SUBNET SERVICE_SUBNET REGISTRY_NAME REGISTRY_PORT
export DATA_DIR LOGS_DIR
export CONTROL_PLANE_SYSTEM_RESERVED CONTROL_PLANE_KUBE_RESERVED 
export ML_NODE_SYSTEM_RESERVED ML_NODE_KUBE_RESERVED
export WORKER_NODE_SYSTEM_RESERVED WORKER_NODE_KUBE_RESERVED
export AUDIT_LOG_MAXAGE AUDIT_LOG_MAXBACKUP AUDIT_LOG_MAXSIZE

.PHONY: list-clusters
list-clusters:
	@echo "Listing all Kind clusters..."
	@kind get clusters

.PHONY: clean-clusters
clean-clusters:
	@echo "Deleting all Kind clusters..."
	@kind get clusters | xargs -n 1 kind delete cluster --name

.PHONY: clean-cluster
clean-cluster:
	@echo "Deleting Kind cluster named $(CLUSTER_NAME)..."
	@kind delete cluster --name $(CLUSTER_NAME)


.PHONY: generate-config
generate-config:
	@echo "Generating Kind config from template..."
	@envsubst < $(CONFIG_TEMPLATE) > $(CONFIG_FILE)

.PHONY: create-cluster
create-cluster: generate-config
	@echo "Creating Kind cluster named $(CLUSTER_NAME)..."
	kind create cluster --name $(CLUSTER_NAME) --config $(CONFIG_FILE)

.PHONY: load-image
load-image:
	@echo "Loading Docker image $(DOCKER_IMAGE) into Kind cluster $(CLUSTER_NAME)..."
	kind load docker-image $(DOCKER_IMAGE) --name $(CLUSTER_NAME)

.PHONY: check-prerequisites
check-prerequisites:
	@echo "Checking prerequisites..."
	@command -v kind >/dev/null 2>&1 || { echo "Error: kind is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed"; exit 1; }
	@echo "All prerequisites installed ✓"

.PHONY: create-directories
create-directories:
	@echo "Creating directories for volume mounts..."
	@mkdir -p $(DATA_DIR) $(LOGS_DIR)

.PHONY: wait-for-cluster
wait-for-cluster:
	@echo "Waiting for cluster nodes to be ready..."
	@kubectl wait --for=condition=Ready nodes --all --timeout=120s

.PHONY: install-ingress
install-ingress:
	@echo "Installing NGINX Ingress Controller..."
	@kubectl apply -f $(NGINX_INGRESS_URL)
	@echo "Waiting for ingress controller to be ready..."
	@kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s

.PHONY: install-storage
install-storage:
	@echo "Installing local-path storage provisioner..."
	@kubectl apply -f $(LOCAL_PATH_PROVISIONER_URL)

.PHONY: install-metrics-server
install-metrics-server:
	@echo "Installing metrics-server..."
	@kubectl apply -f $(METRICS_SERVER_URL)
	@kubectl patch deployment metrics-server -n kube-system --type='json' \
		-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

.PHONY: create-namespaces
create-namespaces:
	@echo "Creating namespaces..."
	@for ns in $(NAMESPACES); do \
		kubectl create namespace $$ns --dry-run=client -o yaml | kubectl apply -f -; \
	done

.PHONY: create-registry
create-registry:
	@echo "Creating local Docker registry..."
	@docker run -d --restart=always -p $(REGISTRY_PORT):5000 --name $(REGISTRY_NAME) registry:2 || true
	@echo "Connecting registry to kind network..."
	@docker network connect "kind" $(REGISTRY_NAME) || true

.PHONY: label-nodes
label-nodes:
	@echo "Labeling nodes..."
	@kubectl get nodes -o name | grep worker | head -1 | xargs -I {} kubectl label {} node-type=compute --overwrite || true
	@kubectl get nodes -o name | grep worker | sed -n '2p' | xargs -I {} kubectl label {} node-type=ml --overwrite || true
	@kubectl get nodes -o name | grep worker | sed -n '3p' | xargs -I {} kubectl label {} node-type=storage --overwrite || true

.PHONY: setup-cluster
setup-cluster: check-prerequisites create-directories create-cluster wait-for-cluster install-ingress install-storage install-metrics-server create-namespaces create-registry label-nodes
	@echo ""
	@echo "✓ Kind cluster setup complete!"
	@echo ""
	@echo "Cluster Info:"
	@echo "- Name: $(CLUSTER_NAME)"
	@echo "- API Server: https://localhost:6443"
	@echo "- Ingress: http://localhost (HTTP) / https://localhost (HTTPS)"
	@echo "- Local Registry: localhost:$(REGISTRY_PORT)"
	@echo ""
	@echo "Namespaces created: $(NAMESPACES)"
	@echo ""
	@echo "To use the cluster:"
	@echo "  kubectl config use-context kind-$(CLUSTER_NAME)"
	@echo ""
	@echo "To delete the cluster:"
	@echo "  make clean-cluster"

.PHONY: destroy-all
destroy-all: clean-cluster
	@echo "Removing local registry..."
	@docker rm -f $(REGISTRY_NAME) || true
	@echo "Removing directories..."
	@rm -rf $(DATA_DIR) $(LOGS_DIR)
	@echo "Cleanup complete!"
