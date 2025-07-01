# Infrastructure Makefile
.PHONY: help init-local init-dev init-staging init-prod plan-local plan-dev plan-staging plan-prod apply-local apply-dev apply-staging apply-prod clean format validate test

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