# =============================================================================
# ML Platform Infrastructure Makefile
# =============================================================================

# Define all PHONY targets
.PHONY: help setup test lint format clean docker-up docker-down docker-detect-socket docker-get-socket docker-status docker-reconfigure registry-up registry-down registry-login dev-kind-up dev-kind-down dev-kind-cleanup dev-aws-up dev-aws-down staging-aws-up staging-aws-down prod-aws-up prod-aws-down eks-configure-kubectl eks-status eks-github-up eks-github-down eks-plan eks-validate frontend-access frontend-build backend-build dev-build-push service-status dev-logs dev-status deploy-dev deploy-staging deploy-prod debug-paths

# =============================================================================
# PATH CONFIGURATION
# =============================================================================
# Current directory (infrastructure/)
CURRENT_DIR := $(shell pwd)
# Project root directory (one level up from infrastructure/)
PROJECT_ROOT := $(shell dirname $(CURRENT_DIR))
# Infrastructure directory (current directory)
INFRA_DIR := $(CURRENT_DIR)

# Source code directories
SRC_DIR := $(PROJECT_ROOT)/src
BACKEND_DIR := $(SRC_DIR)/backend
FRONTEND_DIR := $(SRC_DIR)/frontend

# Terraform directories
TERRAFORM_DIR := $(INFRA_DIR)/terraform
TERRAFORM_ENVS := $(TERRAFORM_DIR)/environments
TERRAFORM_LOCAL := $(TERRAFORM_ENVS)/local
TERRAFORM_DEV := $(TERRAFORM_ENVS)/dev
TERRAFORM_STAGING := $(TERRAFORM_ENVS)/staging
TERRAFORM_PROD := $(TERRAFORM_ENVS)/prod

# Kubernetes directories
K8S_DIR := $(INFRA_DIR)/kubernetes
K8S_OVERLAYS := $(K8S_DIR)/overlays
K8S_LOCAL := $(K8S_OVERLAYS)/local
K8S_DEV := $(K8S_OVERLAYS)/dev
K8S_STAGING := $(K8S_OVERLAYS)/staging
K8S_PROD := $(K8S_OVERLAYS)/prod

# Test directories
TESTS_DIR := $(INFRA_DIR)/tests
PYTHON_TESTS := $(PROJECT_ROOT)/tests

# Other directories
LOCAL_REGISTRY_DIR := $(INFRA_DIR)/local-registry
SCRIPTS_DIR := $(INFRA_DIR)/scripts

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================
# Docker configuration
DOCKER_SOCKET_MACOS := unix://$(HOME)/.docker/run/docker.sock
DOCKER_SOCKET_LINUX := unix:///var/run/docker.sock
DOCKER_CONFIG_FILE := $(INFRA_DIR)/.docker-config

# Registry configuration
LOCAL_REGISTRY_URL := localhost:5001
LOCAL_REGISTRY_USER := $(shell echo $${REGISTRY_USERNAME:-dev})
LOCAL_REGISTRY_PASS := $(shell echo $${REGISTRY_PASSWORD:-})

# Cluster configuration
KIND_CLUSTER_NAME := ml-platform-local
NAMESPACE := ml-platform

# AWS configuration
AWS_REGION := us-west-2
TF_STATE_BUCKET := ml-platform-terraform-state

# Image configuration
BACKEND_IMAGE := ml-platform/backend
FRONTEND_IMAGE := ml-platform/frontend
IMAGE_TAG_DEV := latest
IMAGE_TAG_PROD := v1.0.0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# Detect operating system
OS_TYPE := $(shell uname -s)
IS_MACOS := $(shell [[ "$(OS_TYPE)" == "Darwin" ]] && echo true || echo false)

# Docker socket detection and configuration
docker-detect-socket:
	@echo "🔍 Detecting Docker socket configuration..."
	@DOCKER_HOST=""; \
	if [[ "$(IS_MACOS)" == "true" ]]; then \
		echo "📱 Detected macOS system"; \
		if [[ -S "$(HOME)/.docker/run/docker.sock" ]]; then \
			DOCKER_HOST="$(DOCKER_SOCKET_MACOS)"; \
			echo "✅ Found macOS Docker Desktop socket: $$DOCKER_HOST"; \
		elif [[ -S "/var/run/docker.sock" ]]; then \
			DOCKER_HOST="$(DOCKER_SOCKET_LINUX)"; \
			echo "✅ Found standard Docker socket: $$DOCKER_HOST"; \
		else \
			echo "❌ No Docker socket found. Is Docker running?"; \
			echo "💡 Try starting Docker Desktop or check Docker installation"; \
			exit 1; \
		fi; \
	else \
		echo "🐧 Detected Linux/Unix system"; \
		if [[ -S "/var/run/docker.sock" ]]; then \
			DOCKER_HOST="$(DOCKER_SOCKET_LINUX)"; \
			echo "✅ Found standard Docker socket: $$DOCKER_HOST"; \
		elif [[ -S "$(HOME)/.docker/run/docker.sock" ]]; then \
			DOCKER_HOST="$(DOCKER_SOCKET_MACOS)"; \
			echo "✅ Found user Docker socket: $$DOCKER_HOST"; \
		else \
			echo "❌ No Docker socket found. Is Docker running?"; \
			echo "💡 Try: sudo systemctl start docker"; \
			exit 1; \
		fi; \
	fi; \
	echo "🧪 Testing Docker connection..."; \
	if DOCKER_HOST=$$DOCKER_HOST docker info >/dev/null 2>&1; then \
		echo "✅ Docker connection successful"; \
		echo "$$DOCKER_HOST" > $(DOCKER_CONFIG_FILE); \
		echo "💾 Docker socket saved to $(DOCKER_CONFIG_FILE)"; \
	else \
		echo "❌ Docker connection failed with socket: $$DOCKER_HOST"; \
		echo "💡 Check if Docker daemon is running and accessible"; \
		exit 1; \
	fi

# Get Docker socket from config file or detect it
docker-get-socket:
	@if [[ -f "$(DOCKER_CONFIG_FILE)" ]]; then \
		DOCKER_HOST=$$(cat $(DOCKER_CONFIG_FILE)); \
		if DOCKER_HOST=$$DOCKER_HOST docker info >/dev/null 2>&1; then \
			echo "$$DOCKER_HOST"; \
		else \
			echo "🔄 Cached Docker socket not working, re-detecting..."; \
			$(MAKE) docker-detect-socket >/dev/null; \
			cat $(DOCKER_CONFIG_FILE); \
		fi; \
	else \
		echo "🔍 No cached Docker config, detecting..."; \
		$(MAKE) docker-detect-socket >/dev/null; \
		cat $(DOCKER_CONFIG_FILE); \
	fi

# Setup Docker environment with auto-detection
define setup_docker_env
	@DOCKER_HOST=$$($(MAKE) docker-get-socket 2>/dev/null || echo ""); \
	if [[ -z "$$DOCKER_HOST" ]]; then \
		echo "❌ Failed to configure Docker socket"; \
		exit 1; \
	fi; \
	export DOCKER_HOST=$$DOCKER_HOST; \
	echo "🐳 Using Docker socket: $$DOCKER_HOST"
endef

# Docker status check
docker-status:
	@echo "🐳 Docker Configuration Status:"
	@echo ""
	@if [[ -f "$(DOCKER_CONFIG_FILE)" ]]; then \
		CACHED_HOST=$$(cat $(DOCKER_CONFIG_FILE)); \
		echo "📁 Cached socket: $$CACHED_HOST"; \
		if DOCKER_HOST=$$CACHED_HOST docker info >/dev/null 2>&1; then \
			echo "✅ Status: Working"; \
			echo "🏷️  Docker version: $$(DOCKER_HOST=$$CACHED_HOST docker --version)"; \
			echo "📊 Containers: $$(DOCKER_HOST=$$CACHED_HOST docker ps -q | wc -l | tr -d ' ') running"; \
		else \
			echo "❌ Status: Not working"; \
			echo "🔄 Run 'make docker-detect-socket' to reconfigure"; \
		fi; \
	else \
		echo "📁 No cached configuration"; \
		echo "🔍 Run 'make docker-detect-socket' to configure"; \
	fi; \
	echo ""; \
	echo "💡 Available sockets to check:"; \
	echo "   macOS Docker Desktop: $(DOCKER_SOCKET_MACOS)"; \
	echo "   Standard Linux:       $(DOCKER_SOCKET_LINUX)"; \
	echo ""; \
	echo "🗂️  Config file: $(DOCKER_CONFIG_FILE)"

# Force Docker reconfiguration
docker-reconfigure:
	@echo "🔄 Forcing Docker socket reconfiguration..."
	@rm -f $(DOCKER_CONFIG_FILE)
	@$(MAKE) docker-detect-socket

# =============================================================================
# HELP COMMAND
# =============================================================================
help:
	@echo "ML Platform Infrastructure - Available Commands:"
	@echo ""
	@echo "Development Environment:"
	@echo "  setup            - Set up development environment"
	@echo "  test             - Run all tests"
	@echo "  lint             - Run linters"
	@echo "  format           - Format code"
	@echo "  clean            - Clean build artifacts"
	@echo ""
	@echo "Docker Services:"
	@echo "  docker-up           - Start Docker services"
	@echo "  docker-down         - Stop Docker services"
	@echo "  docker-detect-socket - Detect and configure Docker socket"
	@echo "  docker-status       - Show Docker configuration status"
	@echo "  docker-reconfigure  - Force Docker socket reconfiguration"
	@echo ""
	@echo "Local Registry:"
	@echo "  registry-up      - Start local Docker registry"
	@echo "  registry-down    - Stop local Docker registry"
	@echo "  registry-login   - Login to local Docker registry"
	@echo ""
	@echo "Kind Cluster (Local Development):"
	@echo "  dev-kind-up      - Start Kind cluster with local registry"
	@echo "  dev-kind-down    - Stop Kind cluster"
	@echo ""
	@echo "AWS EKS Cluster Management:"
	@echo "  dev-aws-up       - Start AWS EKS development environment"
	@echo "  dev-aws-down     - Stop AWS EKS development environment"
	@echo "  staging-aws-up   - Start AWS EKS staging environment"
	@echo "  staging-aws-down - Stop AWS EKS staging environment"
	@echo "  prod-aws-up      - Start AWS EKS production environment"
	@echo "  prod-aws-down    - Stop AWS EKS production environment"
	@echo ""
	@echo "EKS Utilities:"
	@echo "  eks-status       - Show EKS cluster status (ENV=dev|staging|prod)"
	@echo "  eks-configure-kubectl - Configure kubectl for EKS"
	@echo "  eks-plan         - Plan Terraform changes (ENV=dev|staging|prod)"
	@echo "  eks-validate     - Validate Terraform configuration"
	@echo ""
	@echo "GitHub Actions (CI/CD):"
	@echo "  eks-github-up    - Start EKS for GitHub Actions (ENV=dev|staging|prod)"
	@echo "  eks-github-down  - Stop EKS for GitHub Actions (ENV=dev|staging|prod)"
	@echo ""
	@echo "Application Management:"
	@echo "  frontend-access  - Access frontend via port forwarding"
	@echo "  frontend-build   - Build and deploy frontend only"
	@echo "  backend-build    - Build and deploy backend only"
	@echo "  dev-build-push   - Build and deploy all services"
	@echo "  service-status   - Quick status check for all services"
	@echo "  dev-logs         - Show application logs"
	@echo "  dev-status       - Show development environment status"
	@echo ""
	@echo "Direct Deployment:"
	@echo "  deploy-dev       - Deploy to dev environment"
	@echo "  deploy-staging   - Deploy to staging environment"
	@echo "  deploy-prod      - Deploy to prod environment"
	@echo ""
	@echo "Configuration:"
	@echo "  PROJECT_ROOT:    $(PROJECT_ROOT)"
	@echo "  INFRA_DIR:       $(INFRA_DIR)"
	@echo "  REGISTRY:        $(LOCAL_REGISTRY_URL)"
	@echo ""
	@echo "Security Configuration:"
	@echo "  Copy .env.example to .env and set secure passwords"
	@echo "  Environment variables: REGISTRY_USERNAME, REGISTRY_PASSWORD"

# =============================================================================
# DEVELOPMENT ENVIRONMENT
# =============================================================================
setup:
	@echo "Setting up development environment..."
	@echo "Project root: $(PROJECT_ROOT)"
	pip install -r $(PROJECT_ROOT)/requirements-dev.txt
	cd $(FRONTEND_DIR) && npm install
	cd $(PROJECT_ROOT) && pre-commit install

test:
	@echo "Running tests..."
	pytest $(PYTHON_TESTS)/
	cd $(FRONTEND_DIR) && npm test

lint:
	@echo "Running linters..."
	flake8 $(SRC_DIR)/
	black --check $(SRC_DIR)/
	cd $(FRONTEND_DIR) && npm run lint

format:
	@echo "Formatting code..."
	black $(SRC_DIR)/
	isort $(SRC_DIR)/
	cd $(FRONTEND_DIR) && npm run format

clean:
	@echo "Cleaning build artifacts..."
	find $(PROJECT_ROOT) -type d -name "__pycache__" -exec rm -rf {} +
	find $(PROJECT_ROOT) -type f -name "*.pyc" -delete
	rm -rf $(PROJECT_ROOT)/.pytest_cache
	rm -rf $(PROJECT_ROOT)/htmlcov
	rm -rf $(PROJECT_ROOT)/dist
	rm -rf $(PROJECT_ROOT)/build
	rm -rf $(PROJECT_ROOT)/*.egg-info

# =============================================================================
# DOCKER SERVICES
# =============================================================================
docker-up:
	@echo "Starting Docker services..."
	cd $(PROJECT_ROOT) && docker-compose up -d

docker-down:
	@echo "Stopping Docker services..."
	cd $(PROJECT_ROOT) && docker-compose down

docker-logs:
	@echo "Showing Docker logs..."
	cd $(PROJECT_ROOT) && docker-compose logs -f

# =============================================================================
# LOCAL REGISTRY
# =============================================================================
registry-up:
	@echo "Starting local Docker registry..."
	@if [[ -d "$(LOCAL_REGISTRY_DIR)" ]]; then \
		cd $(LOCAL_REGISTRY_DIR) && ./setup.sh; \
	else \
		echo "Local registry setup not found at $(LOCAL_REGISTRY_DIR)"; \
	fi

registry-down:
	@echo "Stopping local Docker registry..."
	@if [[ -d "$(LOCAL_REGISTRY_DIR)" ]]; then \
		cd $(LOCAL_REGISTRY_DIR) && docker compose down; \
	else \
		echo "Local registry not found at $(LOCAL_REGISTRY_DIR)"; \
	fi

registry-login:
	@echo "Logging into local Docker registry..."
	@if [[ -z "$(LOCAL_REGISTRY_PASS)" ]]; then \
		echo "⚠️  No registry password set. Registry may not require authentication."; \
		echo "💡 Set REGISTRY_PASSWORD environment variable if authentication is needed."; \
	else \
		docker login $(LOCAL_REGISTRY_URL) -u $(LOCAL_REGISTRY_USER) -p $(LOCAL_REGISTRY_PASS); \
	fi

registry-status:
	@echo "Checking registry status..."
	@curl -s -k https://$(LOCAL_REGISTRY_URL)/v2/_catalog -u $(LOCAL_REGISTRY_USER):$(LOCAL_REGISTRY_PASS) | jq . || echo "Registry is not running or not accessible"

# =============================================================================
# KIND CLUSTER (LOCAL DEVELOPMENT)
# =============================================================================
dev-kind-up:
	@echo "🚀 Starting Kind development environment with Terraform..."
	@echo "📁 Terraform directory: $(TERRAFORM_LOCAL)"
	@echo ""
	$(call setup_docker_env)
	@echo "🧹 Cleaning up any conflicting resources..."
	@$(MAKE) dev-kind-cleanup
	@DOCKER_HOST=$$($(MAKE) docker-get-socket); \
	echo "🏗️  Initializing Terraform..."; \
	cd $(TERRAFORM_LOCAL) && terraform init -upgrade; \
	echo "🚀 Deploying Kind cluster with Docker socket: $$DOCKER_HOST"; \
	cd $(TERRAFORM_LOCAL) && DOCKER_HOST=$$DOCKER_HOST terraform apply -auto-approve \
		-var="registry_username=$(LOCAL_REGISTRY_USER)" \
		-var="registry_password=$(LOCAL_REGISTRY_PASS)"
	@echo ""
	@echo "📦 Applying Kubernetes manifests..."
	kubectl apply -k $(K8S_LOCAL)
	@echo ""
	@echo "✅ Development environment ready!"
	@echo "📱 Frontend: http://localhost:8080"
	@echo "🐳 Registry: http://$(LOCAL_REGISTRY_URL)/v2/_catalog"
	@echo "🔧 Cluster: $(KIND_CLUSTER_NAME)"
	@echo "📊 Status:"
	@$(MAKE) dev-status

dev-kind-down:
	@echo "🔽 Stopping Kind development environment..."
	$(call setup_docker_env)
	@DOCKER_HOST=$$($(MAKE) docker-get-socket); \
	echo "🛑 Destroying Kind cluster with Docker socket: $$DOCKER_HOST"; \
	cd $(TERRAFORM_LOCAL) && DOCKER_HOST=$$DOCKER_HOST terraform destroy -auto-approve
	@echo "🧹 Cleaning up residual resources..."
	@$(MAKE) dev-kind-cleanup
	@echo "✅ Kind environment stopped"

# Clean up orphaned Docker resources that might conflict with Kind deployment
dev-kind-cleanup:
	@echo "🧹 Cleaning up conflicting Docker resources..."
	@DOCKER_HOST=$$($(MAKE) docker-get-socket 2>/dev/null) || DOCKER_HOST=""; \
	if [[ -n "$$DOCKER_HOST" ]]; then \
		echo "🔍 Checking for orphaned Kind containers..."; \
		if DOCKER_HOST=$$DOCKER_HOST docker ps -a --filter "name=kind-registry" --format "{{.Names}}" | grep -q "kind-registry"; then \
			echo "🗑️  Removing orphaned kind-registry container..."; \
			DOCKER_HOST=$$DOCKER_HOST docker rm -f kind-registry 2>/dev/null || true; \
		fi; \
		echo "🔍 Checking for conflicting networks..."; \
		if DOCKER_HOST=$$DOCKER_HOST docker network ls --filter "name=$(KIND_CLUSTER_NAME)-network" --format "{{.Name}}" | grep -q "$(KIND_CLUSTER_NAME)-network"; then \
			echo "🗑️  Removing conflicting network $(KIND_CLUSTER_NAME)-network..."; \
			DOCKER_HOST=$$DOCKER_HOST docker network rm $(KIND_CLUSTER_NAME)-network 2>/dev/null || true; \
		fi; \
		echo "🔍 Cleaning up unused Docker resources..."; \
		DOCKER_HOST=$$DOCKER_HOST docker system prune -f --filter "label=io.x-k8s.kind.cluster=$(KIND_CLUSTER_NAME)" 2>/dev/null || true; \
		echo "✅ Cleanup completed"; \
	else \
		echo "⚠️  Docker not available, skipping cleanup"; \
	fi

# =============================================================================
# AWS EKS CLUSTER MANAGEMENT
# =============================================================================

# EKS Development Environment
dev-aws-up:
	@echo "🚀 Starting AWS EKS development environment..."
	@echo "Environment: dev"
	@echo "Region: $(AWS_REGION)"
	cd $(TERRAFORM_DEV) && terraform init -upgrade
	cd $(TERRAFORM_DEV) && terraform apply -auto-approve
	@echo "⏳ Waiting for EKS cluster to be ready..."
	@$(MAKE) eks-configure-kubectl ENV=dev
	@echo "📦 Applying Kubernetes manifests..."
	kubectl apply -k $(K8S_DEV)
	@echo "✅ AWS EKS development environment ready!"
	@$(MAKE) eks-status ENV=dev

dev-aws-down:
	@echo "🔽 Stopping AWS EKS development environment..."
	cd $(TERRAFORM_DEV) && terraform destroy -auto-approve

# EKS Staging Environment  
staging-aws-up:
	@echo "🚀 Starting AWS EKS staging environment..."
	@echo "Environment: staging"
	@echo "Region: $(AWS_REGION)"
	cd $(TERRAFORM_STAGING) && terraform init -upgrade
	cd $(TERRAFORM_STAGING) && terraform apply -auto-approve
	@echo "⏳ Waiting for EKS cluster to be ready..."
	@$(MAKE) eks-configure-kubectl ENV=staging
	@echo "📦 Applying Kubernetes manifests..."
	kubectl apply -k $(K8S_STAGING)
	@echo "✅ AWS EKS staging environment ready!"
	@$(MAKE) eks-status ENV=staging

staging-aws-down:
	@echo "🔽 Stopping AWS EKS staging environment..."
	cd $(TERRAFORM_STAGING) && terraform destroy -auto-approve

# EKS Production Environment
prod-aws-up:
	@echo "🚀 Starting AWS EKS production environment..."
	@echo "Environment: production"
	@echo "Region: $(AWS_REGION)"
	@echo "⚠️  This will create production resources!"
	@read -p "Are you sure? (yes/no): " confirm && [[ $$confirm == "yes" ]]
	cd $(TERRAFORM_PROD) && terraform init -upgrade
	cd $(TERRAFORM_PROD) && terraform apply
	@echo "⏳ Waiting for EKS cluster to be ready..."
	@$(MAKE) eks-configure-kubectl ENV=prod
	@echo "📦 Applying Kubernetes manifests..."
	kubectl apply -k $(K8S_PROD)
	@echo "✅ AWS EKS production environment ready!"
	@$(MAKE) eks-status ENV=prod

prod-aws-down:
	@echo "🔽 Stopping AWS EKS production environment..."
	@echo "⚠️  This will destroy production resources!"
	@read -p "Are you sure? (yes/no): " confirm && [[ $$confirm == "yes" ]]
	cd $(TERRAFORM_PROD) && terraform destroy

# Configure kubectl for EKS cluster
eks-configure-kubectl:
	@echo "🔧 Configuring kubectl for EKS cluster..."
	@if [[ "$(ENV)" == "dev" ]]; then \
		CLUSTER_NAME=$$(cd $(TERRAFORM_DEV) && terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-dev"); \
	elif [[ "$(ENV)" == "staging" ]]; then \
		CLUSTER_NAME=$$(cd $(TERRAFORM_STAGING) && terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-staging"); \
	elif [[ "$(ENV)" == "prod" ]]; then \
		CLUSTER_NAME=$$(cd $(TERRAFORM_PROD) && terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-prod"); \
	else \
		echo "❌ Invalid environment: $(ENV)"; exit 1; \
	fi; \
	echo "Cluster: $$CLUSTER_NAME"; \
	aws eks update-kubeconfig --region $(AWS_REGION) --name $$CLUSTER_NAME; \
	echo "✅ kubectl configured for EKS cluster"

# Check EKS cluster status
eks-status:
	@echo "📊 EKS Cluster Status ($(ENV)):"
	@echo ""
	@if [[ "$(ENV)" == "dev" ]]; then \
		CLUSTER_NAME=$$(cd $(TERRAFORM_DEV) && terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-dev"); \
	elif [[ "$(ENV)" == "staging" ]]; then \
		CLUSTER_NAME=$$(cd $(TERRAFORM_STAGING) && terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-staging"); \
	elif [[ "$(ENV)" == "prod" ]]; then \
		CLUSTER_NAME=$$(cd $(TERRAFORM_PROD) && terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-prod"); \
	fi; \
	echo "🏠 Current kubectl context: $$(kubectl config current-context)"; \
	echo "🌐 Cluster: $$CLUSTER_NAME"; \
	echo "🔍 Cluster info:"; \
	kubectl cluster-info; \
	echo ""; \
	echo "📊 Node status:"; \
	kubectl get nodes; \
	echo ""; \
	echo "🔍 Pods in $(NAMESPACE) namespace:"; \
	kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "Namespace $(NAMESPACE) not found"; \
	echo ""; \
	echo "🌐 Services in $(NAMESPACE) namespace:"; \
	kubectl get services -n $(NAMESPACE) 2>/dev/null || echo "Namespace $(NAMESPACE) not found"

# GitHub Actions specific commands
eks-github-up:
	@echo "🚀 Starting EKS for GitHub Actions..."
	@echo "Environment: $(ENV)"
	@if [[ -z "$(ENV)" ]]; then echo "❌ ENV variable is required"; exit 1; fi
	@if [[ "$(ENV)" == "dev" ]]; then \
		cd $(TERRAFORM_DEV) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="key=dev/terraform.tfstate" -backend-config="region=$(AWS_REGION)"; \
		cd $(TERRAFORM_DEV) && terraform apply -auto-approve; \
	elif [[ "$(ENV)" == "staging" ]]; then \
		cd $(TERRAFORM_STAGING) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="key=staging/terraform.tfstate" -backend-config="region=$(AWS_REGION)"; \
		cd $(TERRAFORM_STAGING) && terraform apply -auto-approve; \
	elif [[ "$(ENV)" == "prod" ]]; then \
		cd $(TERRAFORM_PROD) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="key=prod/terraform.tfstate" -backend-config="region=$(AWS_REGION)"; \
		cd $(TERRAFORM_PROD) && terraform apply -auto-approve; \
	else \
		echo "❌ Invalid environment: $(ENV)"; exit 1; \
	fi
	@$(MAKE) eks-configure-kubectl ENV=$(ENV)
	@if [[ "$(ENV)" == "dev" ]]; then kubectl apply -k $(K8S_DEV); \
	elif [[ "$(ENV)" == "staging" ]]; then kubectl apply -k $(K8S_STAGING); \
	elif [[ "$(ENV)" == "prod" ]]; then kubectl apply -k $(K8S_PROD); fi
	@echo "✅ EKS cluster ready for GitHub Actions"

eks-github-down:
	@echo "🔽 Stopping EKS for GitHub Actions..."
	@echo "Environment: $(ENV)"
	@if [[ -z "$(ENV)" ]]; then echo "❌ ENV variable is required"; exit 1; fi
	@if [[ "$(ENV)" == "dev" ]]; then \
		cd $(TERRAFORM_DEV) && terraform destroy -auto-approve; \
	elif [[ "$(ENV)" == "staging" ]]; then \
		cd $(TERRAFORM_STAGING) && terraform destroy -auto-approve; \
	elif [[ "$(ENV)" == "prod" ]]; then \
		cd $(TERRAFORM_PROD) && terraform destroy -auto-approve; \
	else \
		echo "❌ Invalid environment: $(ENV)"; exit 1; \
	fi

# Plan only (useful for GitHub Actions PR checks)
eks-plan:
	@echo "📋 Planning EKS changes..."
	@echo "Environment: $(ENV)"
	@if [[ -z "$(ENV)" ]]; then echo "❌ ENV variable is required"; exit 1; fi
	@if [[ "$(ENV)" == "dev" ]]; then \
		cd $(TERRAFORM_DEV) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="key=dev/terraform.tfstate" -backend-config="region=$(AWS_REGION)"; \
		cd $(TERRAFORM_DEV) && terraform plan; \
	elif [[ "$(ENV)" == "staging" ]]; then \
		cd $(TERRAFORM_STAGING) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="key=staging/terraform.tfstate" -backend-config="region=$(AWS_REGION)"; \
		cd $(TERRAFORM_STAGING) && terraform plan; \
	elif [[ "$(ENV)" == "prod" ]]; then \
		cd $(TERRAFORM_PROD) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="key=prod/terraform.tfstate" -backend-config="region=$(AWS_REGION)"; \
		cd $(TERRAFORM_PROD) && terraform plan; \
	else \
		echo "❌ Invalid environment: $(ENV)"; exit 1; \
	fi

# Validate EKS infrastructure without applying
eks-validate:
	@echo "✅ Validating EKS infrastructure..."
	@echo "Environment: $(ENV)"
	@if [[ -z "$(ENV)" ]]; then echo "❌ ENV variable is required"; exit 1; fi
	@if [[ "$(ENV)" == "dev" ]]; then \
		cd $(TERRAFORM_DEV) && terraform init -backend=false; \
		cd $(TERRAFORM_DEV) && terraform validate; \
	elif [[ "$(ENV)" == "staging" ]]; then \
		cd $(TERRAFORM_STAGING) && terraform init -backend=false; \
		cd $(TERRAFORM_STAGING) && terraform validate; \
	elif [[ "$(ENV)" == "prod" ]]; then \
		cd $(TERRAFORM_PROD) && terraform init -backend=false; \
		cd $(TERRAFORM_PROD) && terraform validate; \
	else \
		echo "❌ Invalid environment: $(ENV)"; exit 1; \
	fi
	@echo "✅ Infrastructure validation passed"

# =============================================================================
# APPLICATION MANAGEMENT
# =============================================================================
frontend-access:
	@echo "🌐 Setting up frontend access..."
	@echo "Frontend will be available at: http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	@kubectl port-forward -n $(NAMESPACE) svc/frontend 8080:3000

# Build only frontend
frontend-build:
	@echo "🎨 Building frontend image..."
	@if kubectl config current-context | grep -q kind; then \
		echo "📦 Using Kind registry ($(LOCAL_REGISTRY_URL))..."; \
		docker build -t $(LOCAL_REGISTRY_URL)/$(FRONTEND_IMAGE):$(IMAGE_TAG_DEV) $(FRONTEND_DIR); \
		docker push $(LOCAL_REGISTRY_URL)/$(FRONTEND_IMAGE):$(IMAGE_TAG_DEV); \
		echo "✅ Frontend image pushed to local registry"; \
		echo "🔄 Restarting frontend pods..."; \
		kubectl rollout restart deployment/frontend -n $(NAMESPACE); \
		kubectl rollout status deployment/frontend -n $(NAMESPACE); \
	else \
		echo "☁️  Using ECR..."; \
		ECR_URL=$$(terraform -chdir=$(TERRAFORM_DEV) output -raw ecr_repositories | jq -r '.frontend' | cut -d'/' -f1); \
		aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$ECR_URL; \
		docker build -t $$ECR_URL/$(FRONTEND_IMAGE):dev $(FRONTEND_DIR); \
		docker push $$ECR_URL/$(FRONTEND_IMAGE):dev; \
		echo "✅ Frontend image pushed to ECR"; \
		echo "🔄 Restarting frontend pods..."; \
		kubectl rollout restart deployment/frontend -n $(NAMESPACE); \
		kubectl rollout status deployment/frontend -n $(NAMESPACE); \
	fi

# Build only backend
backend-build:
	@echo "⚙️  Building backend image..."
	@if kubectl config current-context | grep -q kind; then \
		echo "📦 Using Kind registry ($(LOCAL_REGISTRY_URL))..."; \
		docker build -t $(LOCAL_REGISTRY_URL)/$(BACKEND_IMAGE):$(IMAGE_TAG_DEV) $(BACKEND_DIR); \
		docker push $(LOCAL_REGISTRY_URL)/$(BACKEND_IMAGE):$(IMAGE_TAG_DEV); \
		echo "✅ Backend image pushed to local registry"; \
		echo "🔄 Restarting backend pods..."; \
		kubectl rollout restart deployment/backend -n $(NAMESPACE); \
		kubectl rollout status deployment/backend -n $(NAMESPACE); \
	else \
		echo "☁️  Using ECR..."; \
		ECR_URL=$$(terraform -chdir=$(TERRAFORM_DEV) output -raw ecr_repositories | jq -r '.backend' | cut -d'/' -f1); \
		aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$ECR_URL; \
		docker build -t $$ECR_URL/$(BACKEND_IMAGE):dev $(BACKEND_DIR); \
		docker push $$ECR_URL/$(BACKEND_IMAGE):dev; \
		echo "✅ Backend image pushed to ECR"; \
		echo "🔄 Restarting backend pods..."; \
		kubectl rollout restart deployment/backend -n $(NAMESPACE); \
		kubectl rollout status deployment/backend -n $(NAMESPACE); \
	fi

# Build all services (original command)
dev-build-push: frontend-build backend-build
	@echo "✅ All images built and deployed"

# Quick status check for services
service-status:
	@echo "📊 Service Status:"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "🌐 Services:"
	@kubectl get svc -n $(NAMESPACE)

dev-logs:
	@echo "Showing development environment logs..."
	kubectl logs -f -l app.kubernetes.io/name=backend -n $(NAMESPACE)

dev-status:
	@echo "Development environment status:"
	@echo ""
	@echo "🏠 Current context: $$(kubectl config current-context)"
	@echo "🔍 Pods in $(NAMESPACE) namespace:"
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "🌐 Services in $(NAMESPACE) namespace:"
	@kubectl get services -n $(NAMESPACE)
	@echo ""
	@echo "📊 Node status:"
	@kubectl get nodes

# =============================================================================
# DIRECT DEPLOYMENT
# =============================================================================
deploy-dev:
	@echo "Deploying to dev environment..."
	cd $(TERRAFORM_DEV) && terraform apply

deploy-staging:
	@echo "Deploying to staging environment..."
	cd $(TERRAFORM_STAGING) && terraform apply

deploy-prod:
	@echo "Deploying to prod environment..."
	cd $(TERRAFORM_PROD) && terraform apply

# =============================================================================
# DEBUG INFORMATION
# =============================================================================
debug-paths:
	@echo "=== PATH CONFIGURATION ==="
	@echo "CURRENT_DIR:      $(CURRENT_DIR)"
	@echo "PROJECT_ROOT:     $(PROJECT_ROOT)"
	@echo "INFRA_DIR:        $(INFRA_DIR)"
	@echo "SRC_DIR:          $(SRC_DIR)"
	@echo "BACKEND_DIR:      $(BACKEND_DIR)"
	@echo "FRONTEND_DIR:     $(FRONTEND_DIR)"
	@echo "TERRAFORM_LOCAL:  $(TERRAFORM_LOCAL)"
	@echo "K8S_LOCAL:        $(K8S_LOCAL)"
	@echo "=== CONFIGURATION ==="
	@echo "OS_TYPE:          $(OS_TYPE)"
	@echo "IS_MACOS:         $(IS_MACOS)"
	@echo "REGISTRY_URL:     $(LOCAL_REGISTRY_URL)"
	@echo "KIND_CLUSTER:     $(KIND_CLUSTER_NAME)"