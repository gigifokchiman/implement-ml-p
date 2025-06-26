# clusters
CLUSTER_NAME ?= ml-platform-sandbox
CONFIG_FILE := kind-sandbox-shared-config.yaml
CONFIG_TEMPLATE := kind-sandbox-config.yaml.tmpl

# versions
K8S_VERSION ?= 1.30.0
POD_SUBNET ?= 10.244.0.0/16
SERVICE_SUBNET ?= 10.96.0.0/12

# Export variables for envsubst
export CLUSTER_NAME K8S_VERSION POD_SUBNET SERVICE_SUBNET

.PHONY: clean-clusters
clean-clusters:
	@echo "Deleting all Kind clusters..."
	@kind get clusters | xargs -n 1 kind delete cluster --name

.PHONY: clean-cluster
clean-cluster:
	@echo "Deleting Kind cluster named $(CLUSTER_NAME)..."
	@kind delete cluster --name $(CLUSTER_NAME)

.PHONY: list-clusters
list-clusters:
	@echo "Listing all Kind clusters..."
	@kind get clusters

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
