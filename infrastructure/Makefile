# Infrastructure Makefile
.PHONY: help init-local init-dev init-staging init-prod plan-local plan-dev plan-staging plan-prod apply-local apply-dev apply-staging apply-prod clean format validate test docker-build docker-run docker-shell docker-stop docker-clean

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Terraform versions by environment
TF_VERSION_LOCAL := 1.5.7
TF_VERSION_DEV := 1.5.7
TF_VERSION_STAGING := 1.5.7
TF_VERSION_PROD := 1.6.0

# Base paths
TF_DIR := terraform/environments
SCRIPTS_DIR := scripts

# Docker configuration
DOCKER_IMAGE := ml-platform/infra-tools
DOCKER_TAG := latest
DOCKER_COMPOSE_FILE := docker-compose.infra.yml
CONTAINER_NAME := ml-platform-infra-tools

help: ## Show this help message
	@echo '$(BLUE)ML Platform Infrastructure Makefile$(NC)'
	@echo ''
	@echo 'Usage:'
	@echo '  $(GREEN)make$(NC) $(YELLOW)<target>$(NC)'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Examples:'
	@echo '  $(GREEN)make init-local$(NC)     Initialize local environment'
	@echo '  $(GREEN)make plan-local$(NC)     Plan changes for local environment'
	@echo '  $(GREEN)make apply-local$(NC)    Apply changes to local environment'

# Local environment targets
init-local: ## Initialize local environment (TF $(TF_VERSION_LOCAL))
	@echo "$(BLUE)🔧 Initializing local environment with Terraform $(TF_VERSION_LOCAL)$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh local init

plan-local: ## Plan local environment changes
	@echo "$(BLUE)📋 Planning local environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh local plan

apply-local: ## Apply local environment changes
	@echo "$(GREEN)🚀 Applying local environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh local apply

destroy-local: ## Destroy local environment (DANGEROUS!)
	@echo "$(RED)💣 Destroying local environment$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh local destroy

# Development environment targets
init-dev: ## Initialize dev environment (TF $(TF_VERSION_DEV))
	@echo "$(BLUE)🔧 Initializing dev environment with Terraform $(TF_VERSION_DEV)$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh dev init

plan-dev: ## Plan dev environment changes
	@echo "$(BLUE)📋 Planning dev environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh dev plan

apply-dev: ## Apply dev environment changes
	@echo "$(GREEN)🚀 Applying dev environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh dev apply

# Staging environment targets
init-staging: ## Initialize staging environment (TF $(TF_VERSION_STAGING))
	@echo "$(BLUE)🔧 Initializing staging environment with Terraform $(TF_VERSION_STAGING)$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh staging init

plan-staging: ## Plan staging environment changes
	@echo "$(BLUE)📋 Planning staging environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh staging plan

apply-staging: ## Apply staging environment changes
	@echo "$(GREEN)🚀 Applying staging environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh staging apply

# Production environment targets
init-prod: ## Initialize prod environment (TF $(TF_VERSION_PROD))
	@echo "$(BLUE)🔧 Initializing prod environment with Terraform $(TF_VERSION_PROD)$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh prod init

plan-prod: ## Plan prod environment changes
	@echo "$(BLUE)📋 Planning prod environment changes$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh prod plan

apply-prod: ## Apply prod environment changes (requires confirmation)
	@echo "$(RED)⚠️  WARNING: This will apply changes to PRODUCTION!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " -r; \
	if [ "$$REPLY" = "yes" ]; then \
		$(SCRIPTS_DIR)/tf-wrapper.sh prod apply; \
	else \
		echo "$(GREEN)✅ Production apply cancelled$(NC)"; \
	fi

# Utility targets
format: ## Format all Terraform files
	@echo "$(GREEN)🎨 Formatting Terraform files$(NC)"
	@cd $(TF_DIR) && terraform fmt -recursive

validate: ## Validate all Terraform configurations
	@echo "$(GREEN)✅ Validating Terraform configurations$(NC)"
	@for env in local dev staging prod; do \
		echo "$(BLUE)Validating $$env...$(NC)"; \
		cd $(TF_DIR)/$$env && terraform init -backend=false && terraform validate; \
	done

clean: ## Clean Terraform cache and temporary files
	@echo "$(YELLOW)🧹 Cleaning Terraform cache$(NC)"
	@find $(TF_DIR) -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find $(TF_DIR) -type f -name ".terraform.lock.hcl" -exec rm -f {} + 2>/dev/null || true
	@find $(TF_DIR) -type f -name "*.tfplan" -exec rm -f {} + 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup completed$(NC)"

deep-clean: ## Deep clean all temporary files, state, and artifacts
	@echo "$(YELLOW)🧹 Running deep infrastructure cleanup$(NC)"
	@$(SCRIPTS_DIR)/cleanup-infrastructure.sh
	@echo "$(GREEN)✅ Deep cleanup completed$(NC)"

test: ## Run infrastructure tests
	@echo "$(BLUE)🧪 Running infrastructure tests$(NC)"
	@cd tests && ./run-all.sh

# Quick local development workflow
local-up: init-local plan-local ## Initialize and plan local environment
	@echo "$(GREEN)✅ Local environment ready for apply$(NC)"

local-down: destroy-local clean ## Destroy local environment and clean up
	@echo "$(GREEN)✅ Local environment destroyed$(NC)"

# Module targets
plan-module-%: ## Plan specific module (e.g., make plan-module-database ENV=local)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)❌ ENV variable required. Usage: make plan-module-database ENV=local$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)📋 Planning module $* in $(ENV) environment$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh $(ENV) plan -target=module.$*

apply-module-%: ## Apply specific module (e.g., make apply-module-database ENV=local)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)❌ ENV variable required. Usage: make apply-module-database ENV=local$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)🚀 Applying module $* in $(ENV) environment$(NC)"
	@$(SCRIPTS_DIR)/tf-wrapper.sh $(ENV) apply -target=module.$* -auto-approve

# Check prerequisites
check-deps: ## Check required dependencies
	@echo "$(BLUE)🔍 Checking dependencies$(NC)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)❌ terraform not found$(NC)"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)❌ kubectl not found$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ docker not found$(NC)"; exit 1; }
	@if command -v tfenv >/dev/null 2>&1; then \
		echo "$(GREEN)✅ tfenv installed$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  tfenv not found (recommended for version management)$(NC)"; \
	fi
	@echo "$(GREEN)✅ All required dependencies found$(NC)"

# Show current infrastructure status
status: ## Show infrastructure status for all environments
	@echo "$(BLUE)📊 Infrastructure Status$(NC)"
	@for env in local dev staging prod; do \
		echo ""; \
		echo "$(YELLOW)$$env environment:$(NC)"; \
		if [ -d "$(TF_DIR)/$$env/.terraform" ]; then \
			cd $(TF_DIR)/$$env && terraform show -json | jq -r '.values.root_module.resources | length' | xargs echo "  Resources:"; \
		else \
			echo "  $(YELLOW)Not initialized$(NC)"; \
		fi \
	done

# Version information
version: ## Show Terraform versions for all environments
	@echo "$(BLUE)📌 Terraform Version Configuration$(NC)"
	@echo ""
	@for env in local dev staging prod; do \
		if [ -f "$(TF_DIR)/$$env/.terraform-version" ]; then \
			version=$$(cat $(TF_DIR)/$$env/.terraform-version); \
			echo "$(GREEN)$$env:$(NC) $$version"; \
		else \
			echo "$(YELLOW)$$env:$(NC) No version file"; \
		fi \
	done
	@echo ""
	@echo "$(BLUE)Current Terraform version:$(NC)"
	@terraform version | head -1

# =============================================================================
# Docker-based Infrastructure Management
# =============================================================================

docker-build: ## Build the infrastructure tools Docker image
	@echo "$(BLUE)🐳 Building infrastructure tools Docker image$(NC)"
	@docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	@echo "$(GREEN)✅ Docker image built successfully$(NC)"

docker-run: ## Run infrastructure tools container in background
	@echo "$(BLUE)🚀 Starting infrastructure tools container$(NC)"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) up -d infra-tools
	@echo "$(GREEN)✅ Container started. Use 'make docker-shell' to access it$(NC)"

docker-shell: ## Open shell in infrastructure tools container
	@echo "$(BLUE)🔗 Opening shell in infrastructure tools container$(NC)"
	@if [ "$$(docker ps -q -f name=$(CONTAINER_NAME))" ]; then \
		docker exec -it $(CONTAINER_NAME) /bin/bash; \
	else \
		echo "$(YELLOW)⚠️  Container not running. Starting it first...$(NC)"; \
		make docker-run && sleep 3 && docker exec -it $(CONTAINER_NAME) /bin/bash; \
	fi

docker-stop: ## Stop infrastructure tools container
	@echo "$(YELLOW)🛑 Stopping infrastructure tools container$(NC)"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) down
	@echo "$(GREEN)✅ Container stopped$(NC)"

docker-clean: ## Clean Docker images and containers
	@echo "$(YELLOW)🧹 Cleaning Docker infrastructure$(NC)"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) down --volumes --rmi all 2>/dev/null || true
	@docker system prune -f
	@echo "$(GREEN)✅ Docker cleanup completed$(NC)"

docker-logs: ## View container logs
	@echo "$(BLUE)📋 Infrastructure tools container logs$(NC)"
	@docker-compose -f $(DOCKER_COMPOSE_FILE) logs -f infra-tools

docker-health: ## Check container health
	@echo "$(BLUE)🏥 Checking container health$(NC)"
	@if [ "$$(docker ps -q -f name=$(CONTAINER_NAME))" ]; then \
		docker exec $(CONTAINER_NAME) /usr/local/bin/health-check.sh; \
	else \
		echo "$(RED)❌ Container not running$(NC)"; \
	fi

# Docker-based Terraform commands
docker-init-%: ## Initialize environment using Docker (e.g., make docker-init-local)
	@echo "$(BLUE)🔧 Initializing $* environment using Docker$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c "cd terraform/environments/$* && terraform init"

docker-plan-%: ## Plan environment using Docker (e.g., make docker-plan-local)
	@echo "$(BLUE)📋 Planning $* environment using Docker$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c "cd terraform/environments/$* && terraform plan"

docker-apply-%: ## Apply environment using Docker (e.g., make docker-apply-local)
	@echo "$(GREEN)🚀 Applying $* environment using Docker$(NC)"
	@if [ "$*" = "prod" ]; then \
		echo "$(RED)⚠️  WARNING: This will apply changes to PRODUCTION!$(NC)"; \
		read -p "Are you sure? Type 'yes' to continue: " -r; \
		if [ "$$REPLY" = "yes" ]; then \
			docker exec $(CONTAINER_NAME) bash -c "cd terraform/environments/$* && terraform apply"; \
		else \
			echo "$(GREEN)✅ Production apply cancelled$(NC)"; \
		fi \
	else \
		docker exec $(CONTAINER_NAME) bash -c "cd terraform/environments/$* && terraform apply"; \
	fi

docker-format: ## Format Terraform files using Docker
	@echo "$(GREEN)🎨 Formatting Terraform files using Docker$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c "cd terraform && terraform fmt -recursive"

docker-validate: ## Validate Terraform configurations using Docker
	@echo "$(GREEN)✅ Validating Terraform configurations using Docker$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c "cd terraform && for env in environments/*/; do echo 'Validating \$$env...'; cd \$$env && terraform init -backend=false && terraform validate && cd ../..; done"

docker-test: ## Run infrastructure tests using Docker
	@echo "$(BLUE)🧪 Running infrastructure tests using Docker$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c "cd tests && ./run-tests.sh"

docker-security-scan: ## Run security scans using Docker
	@echo "$(BLUE)🔒 Running security scans using Docker$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c "cd terraform && checkov -d . --framework terraform"
	@docker exec $(CONTAINER_NAME) bash -c "cd terraform && tfsec ."

# Docker development workflow
docker-dev-setup: docker-build docker-run ## Complete Docker development setup
	@echo "$(GREEN)✅ Docker development environment ready$(NC)"
	@echo "$(BLUE)Use the following commands:$(NC)"
	@echo "  $(GREEN)make docker-shell$(NC)       - Access container shell"
	@echo "  $(GREEN)make docker-init-local$(NC)  - Initialize local environment"
	@echo "  $(GREEN)make docker-plan-local$(NC)  - Plan local changes"
	@echo "  $(GREEN)make docker-apply-local$(NC) - Apply local changes"

docker-dev-teardown: docker-stop docker-clean ## Teardown Docker development environment
	@echo "$(GREEN)✅ Docker development environment cleaned up$(NC)"

# Combined native and Docker status
full-status: status docker-health ## Show complete infrastructure status
	@echo "$(BLUE)🐳 Docker Infrastructure Status$(NC)"

# Help for Docker commands
docker-help: ## Show Docker-specific help
	@echo "$(BLUE)🐳 Docker Infrastructure Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup Commands:$(NC)"
	@echo "  $(GREEN)make docker-build$(NC)        Build infrastructure tools image"
	@echo "  $(GREEN)make docker-run$(NC)          Start container in background"
	@echo "  $(GREEN)make docker-shell$(NC)        Open shell in container"
	@echo ""
	@echo "$(YELLOW)Terraform Commands:$(NC)"
	@echo "  $(GREEN)make docker-init-ENV$(NC)     Initialize environment (local/dev/staging/prod)"
	@echo "  $(GREEN)make docker-plan-ENV$(NC)     Plan changes for environment"
	@echo "  $(GREEN)make docker-apply-ENV$(NC)    Apply changes to environment"
	@echo ""
	@echo "$(YELLOW)Utility Commands:$(NC)"
	@echo "  $(GREEN)make docker-format$(NC)       Format Terraform files"
	@echo "  $(GREEN)make docker-validate$(NC)     Validate configurations"
	@echo "  $(GREEN)make docker-test$(NC)         Run infrastructure tests"
	@echo "  $(GREEN)make docker-security-scan$(NC) Run security scans"
	@echo ""
	@echo "$(YELLOW)Management Commands:$(NC)"
	@echo "  $(GREEN)make docker-logs$(NC)         View container logs"
	@echo "  $(GREEN)make docker-health$(NC)       Check container health"
	@echo "  $(GREEN)make docker-stop$(NC)         Stop container"
	@echo "  $(GREEN)make docker-clean$(NC)        Clean up Docker resources"

# =============================================================================
# ArgoCD GitOps Management
# =============================================================================

argocd-bootstrap: ## Bootstrap ArgoCD for GitOps (ENV=local)
	@echo "$(BLUE)🚀 Bootstrapping ArgoCD for $(ENV) environment$(NC)"
	@$(SCRIPTS_DIR)/bootstrap-argocd.sh $(ENV)

argocd-dashboard: ## Open ArgoCD dashboard
	@echo "$(BLUE)📊 Opening ArgoCD dashboard$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh dashboard

argocd-login: ## Login to ArgoCD CLI
	@echo "$(BLUE)🔐 Logging into ArgoCD$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh login

argocd-password: ## Get ArgoCD admin password
	@echo "$(BLUE)🔑 ArgoCD admin password:$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh password

argocd-apps: ## List all ArgoCD applications
	@echo "$(BLUE)📋 ArgoCD Applications$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh list

argocd-status: ## Show status of all applications
	@echo "$(BLUE)📊 ArgoCD Applications Status$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh apps

argocd-sync-%: ## Sync specific application (e.g., make argocd-sync-ml-platform-local)
	@echo "$(GREEN)🔄 Syncing ArgoCD application: $*$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh sync $*

argocd-health: ## Check ArgoCD health
	@echo "$(BLUE)🏥 Checking ArgoCD health$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh health

argocd-logs-%: ## Show logs for specific application
	@echo "$(BLUE)📋 Logs for application: $*$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh logs $*

argocd-debug-%: ## Debug specific application issues
	@echo "$(BLUE)🔍 Debugging application: $*$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh debug $*

# ArgoCD help
argocd-help: ## Show ArgoCD-specific help
	@echo "$(BLUE)🚀 ArgoCD GitOps Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup Commands:$(NC)"
	@echo "  $(GREEN)make argocd-bootstrap ENV=local$(NC)  Bootstrap ArgoCD"
	@echo "  $(GREEN)make argocd-login$(NC)               Login to ArgoCD CLI"
	@echo "  $(GREEN)make argocd-dashboard$(NC)           Open ArgoCD UI"
	@echo ""
	@echo "$(YELLOW)Application Management:$(NC)"
	@echo "  $(GREEN)make argocd-apps$(NC)                List all applications"
	@echo "  $(GREEN)make argocd-status$(NC)              Show all app status"
	@echo "  $(GREEN)make argocd-sync-APP$(NC)            Sync specific app"
	@echo "  $(GREEN)make argocd-logs-APP$(NC)            Show app logs"
	@echo "  $(GREEN)make argocd-debug-APP$(NC)           Debug app issues"
	@echo ""
	@echo "$(YELLOW)System Commands:$(NC)"
	@echo "  $(GREEN)make argocd-health$(NC)              Check ArgoCD health"
	@echo "  $(GREEN)make argocd-password$(NC)            Get admin password"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  $(GREEN)make argocd-bootstrap ENV=local$(NC)"
	@echo "  $(GREEN)make argocd-sync-ml-platform-local$(NC)"
	@echo "  $(GREEN)make argocd-debug-ml-platform-prod$(NC)"