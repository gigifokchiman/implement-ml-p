# clusters
CLUSTER_NAME := ml-sandbox
CONFIG_FILE := kind-sandbox-shared-config.yaml

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

.PHONY: create-cluster
create-cluster:
	@echo "Creating Kind cluster named $(CLUSTER_NAME)..."
	kind create cluster --name $(CLUSTER_NAME) --config $(CONFIG_FILE)

.PHONY: load-image
load-image:
	@echo "Loading Docker image $(DOCKER_IMAGE) into Kind cluster $(CLUSTER_NAME)..."
	kind load docker-image $(DOCKER_IMAGE) --name $(CLUSTER_NAME)
