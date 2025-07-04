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
DOCKER_IMAGE := data-platform/infra-tools
DOCKER_TAG := latest
DOCKER_COMPOSE_FILE := docker-compose.infra.yml
CONTAINER_NAME := data-platform-infra-tools

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
	@echo '  $(GREEN)make deploy-local$(NC)       Deploy local ML platform (clean)'
	@echo '  $(GREEN)make deploy-platform$(NC)    Deploy complete platform stack'
	@echo '  $(GREEN)make check-labels$(NC)       Check resource compliance'
	@echo '  $(GREEN)make local-down$(NC)         Cleanup local environment'

# =============================================================================
# Terraform Infrastructure Management
# =============================================================================
init-tf-local: ## (TF-LOCAL) Initialize local terraform
	@echo "$(BLUE)🔧 Initializing local Terraform$(NC)"
	@cd terraform/environments/local && rm -f .terraform.lock.hcl && rm -rf .terraform && terraform init --upgrade

plan-tf-local: ## (TF-LOCAL) Plan local terraform changes
	@echo "$(BLUE)📋 Planning local Terraform changes$(NC)"
	@cd terraform/environments/local && terraform plan

apply-tf-local: ## (TF-LOCAL) Apply local terraform changes
	@echo "$(GREEN)🚀 Applying local Terraform changes$(NC)"
	@cd terraform/environments/local && terraform apply -auto-approve

clean-tf-local: ## (TF-LOCAL) Destroy local environment (uses terraform destroy)
	@echo "$(RED)💣 Destroying local environment$(NC)"
	@cd terraform/environments/local && terraform destroy -auto-approve
	@cd terraform/environments/local && rm -f .terraform.lock.hcl && rm -rf .terraform
	@kind get clusters | xargs -I {} kind delete cluster --name {}

# Target-specific terraform operations
apply-cluster-tf-local: ## (TF-LOCAL) Apply only the data platform cluster
	@echo "$(BLUE)🐳 Creating data platform cluster$(NC)"
	@cd terraform/environments/local && terraform apply -target=kind_cluster.data_platform -auto-approve

# kubectl context setup
setup-kubectl-local: ## Configure kubectl context for local cluster
	@echo "$(BLUE)⚙️ Configuring kubectl context$(NC)"
	@kubectl config use-context kind-data-platform-local

# TODO: review it
# Storage provisioner setup
setup-storage-local: ## Install and configure local-path-provisioner - this solves error about the storage.
	@echo "$(BLUE)💾 Setting up storage provisioner$(NC)"
	@if ! kubectl get deployment -n local-path-storage local-path-provisioner 2>/dev/null; then \
		echo "📦 Installing local-path-provisioner..."; \
		kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml; \
	fi
	@echo "⏳ Waiting for provisioner to be ready..."
	@kubectl wait --for=condition=ready pod -n local-path-storage -l app=local-path-provisioner --timeout=120s
	@kubectl delete storageclass standard --ignore-not-found=true
	@echo "💾 Creating storage class..."
	@kubectl apply -f kubernetes/storage/local-path-storage-class.yaml
	@echo "$(GREEN)✅ Storage provisioner configured!$(NC)"

setup-team-namespaces: ## Create team namespaces with proper labels
	@echo "$(BLUE)👥 Setting up team namespaces$(NC)"
	@kubectl apply -f kubernetes/team-isolation/team-namespaces.yaml
	@echo "$(GREEN)✅ Team namespaces created!$(NC)"

deploy-security-bootstrap-tf-local: ## (TF-LOCAL) Deploy security infrastructure in correct order
	@echo "$(GREEN)🔐 Deploying security bootstrap infrastructure$(NC)"
	@cd terraform/environments/local && terraform apply \
		-target=module.security_bootstrap.helm_release.cert_manager \
		-target=module.security_bootstrap.helm_release.nginx_ingress \
		-target=module.security_bootstrap.time_sleep.wait_for_cert_manager \
		-auto-approve
	@echo "$(YELLOW)⏳ Waiting for CRDs...$(NC)"
	@kubectl wait --for=condition=established --timeout=60s crd/clusterissuers.cert-manager.io
	@echo "$(GREEN)📋 Deploying ClusterIssuers and ArgoCD$(NC)"
	@cd terraform/environments/local && terraform apply \
		-target=module.security_bootstrap.kubernetes_manifest.selfsigned_issuer \
		-target=module.security_bootstrap.kubernetes_manifest.letsencrypt_issuer \
		-target=module.security_bootstrap.helm_release.argocd \
		-target=module.security_bootstrap.helm_release.prometheus \
		-auto-approve
	@echo "$(YELLOW)⏳ Waiting for ArgoCD to be ready...$(NC)"
	@kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s || echo "⚠️  ArgoCD may need more time"
	@echo "$(GREEN)🔒 Applying remaining security bootstrap resources$(NC)"
	@cd terraform/environments/local && terraform apply -target=module.security_bootstrap -auto-approve
	@echo "$(GREEN)✅ Security bootstrap complete with GitOps and Monitoring$(NC)"

# Development environment targets
init-dev: ## (TF-DEV) Initialize dev environment (TF $(TF_VERSION_DEV))
	@echo "$(BLUE)🔧 Initializing dev environment with Terraform $(TF_VERSION_DEV)$(NC)"
	@cd terraform/environments/dev && rm -f .terraform.lock.hcl && rm -rf .terraform && terraform init --upgrade

plan-dev: ## (TF-DEV) Plan dev environment changes
	@echo "$(BLUE)📋 Planning dev environment changes$(NC)"
	@cd terraform/environments/dev && terraform plan

apply-dev: ## (TF-DEV) Apply dev environment changes
	@echo "$(GREEN)🚀 Applying dev environment changes$(NC)"
	@cd terraform/environments/dev && terraform apply -auto-approve

destroy-dev: ## (TF-DEV) Destroy dev environment
	@echo "$(RED)💣 Destroying dev environment$(NC)"
	@cd terraform/environments/dev && terraform destroy -auto-approve

cleanup-dev: ## Clean up dev terraform cache
	@echo "$(YELLOW)🧹 Cleaning up dev terraform$(NC)"
	@cd terraform/environments/dev && rm -rf .terraform .terraform.lock.hcl

# Complete dev deployment
deploy-dev-full: ## Complete dev environment deployment with cleanup
	@echo "$(GREEN)🚀 ML Platform Dev Deployment$(NC)"
	@echo "=================================="
	@echo ""
	@echo "📍 Working in dev environment"
	@echo ""
	@echo "🧹 Cleaning up existing resources..."
	@$(MAKE) destroy-dev || echo "⚠️  No existing dev environment to destroy"
	@$(MAKE) cleanup-dev
	@echo "✅ Cleanup complete"
	@echo ""
	@echo "🔧 Step 1: Setting up Terraform..."
	@$(MAKE) init-dev
	@echo "✅ Terraform provider setup complete"
	@echo ""
	@echo "☁️  Step 2: Creating AWS EKS cluster..."
	@$(MAKE) apply-dev
	@echo ""
	@echo "🔧 Configuring kubectl context..."
	@aws eks update-kubeconfig --region us-west-2 --name data-platform-dev || echo "⚠️  Configure kubectl manually"
	@echo ""
	@echo "🔐 Step 3: Deploying security bootstrap (CRDs)..."
	@cd terraform/environments/dev && terraform apply \
		-target=module.security_bootstrap.helm_release.cert_manager \
		-target=module.security_bootstrap.helm_release.nginx_ingress \
		-auto-approve || echo "⚠️  Security bootstrap may need manual configuration"
	@kubectl wait --for=condition=established --timeout=60s crd/clusterissuers.cert-manager.io || echo "⚠️  CRDs not ready"
	@cd terraform/environments/dev && terraform apply -target=module.security_bootstrap -auto-approve || echo "⚠️  Complete security bootstrap manually"
	@echo ""
	@echo "✅ Step 4: Verifying deployment..."
	@kubectl get nodes || echo "⚠️  Cluster not ready yet"
	@kubectl get namespaces
	@echo ""
	@echo "$(GREEN)🎉 Dev environment deployment completed!$(NC)"
	@echo ""
	@echo "🔗 Next steps:"
	@echo "  1. Configure kubectl: aws eks update-kubeconfig --region us-west-2 --name data-platform-dev"
	@echo "  2. Deploy applications: make deploy-dev-apps"
	@echo "  3. Setup monitoring: make deploy-monitoring"

deploy-dev-quick: ## Quick dev deployment (no cleanup)
	@echo "$(GREEN)⚡ Quick Dev Environment Deployment$(NC)"
	@echo "===================================="
	@$(MAKE) init-dev
	@$(MAKE) apply-dev
	@echo "$(GREEN)✅ Quick dev deployment completed!$(NC)"

# Staging environment targets
init-staging: ## (TF-STAGING) Initialize staging environment (TF $(TF_VERSION_STAGING))
	@echo "$(BLUE)🔧 Initializing staging environment with Terraform $(TF_VERSION_STAGING)$(NC)"
	@cd terraform/environments/staging && rm -f .terraform.lock.hcl && rm -rf .terraform && terraform init --upgrade

plan-staging: ## (TF-STAGING) Plan staging environment changes
	@echo "$(BLUE)📋 Planning staging environment changes$(NC)"
	@cd terraform/environments/staging && terraform plan

apply-staging: ## (TF-STAGING) Apply staging environment changes
	@echo "$(GREEN)🚀 Applying staging environment changes$(NC)"
	@cd terraform/environments/staging && terraform apply -auto-approve

destroy-staging: ## (TF-STAGING) Destroy staging environment
	@echo "$(RED)💣 Destroying staging environment$(NC)"
	@cd terraform/environments/staging && terraform destroy -auto-approve

cleanup-staging: ## Clean up staging terraform cache
	@echo "$(YELLOW)🧹 Cleaning up staging terraform$(NC)"
	@cd terraform/environments/staging && rm -rf .terraform .terraform.lock.hcl

# Production environment targets
init-prod: ## (TF-PROD) Initialize prod environment (TF $(TF_VERSION_PROD))
	@echo "$(BLUE)🔧 Initializing prod environment with Terraform $(TF_VERSION_PROD)$(NC)"
	@cd terraform/environments/prod && rm -f .terraform.lock.hcl && rm -rf .terraform && terraform init --upgrade

plan-prod: ## (TF-PROD) Plan prod environment changes
	@echo "$(BLUE)📋 Planning prod environment changes$(NC)"
	@cd terraform/environments/prod && terraform plan

apply-prod: ## (TF-PROD) Apply prod environment changes (requires confirmation)
	@echo "$(RED)⚠️  WARNING: This will apply changes to PRODUCTION!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " -r; \
	if [ "$$REPLY" = "yes" ]; then \
		cd terraform/environments/prod && terraform apply; \
	else \
		echo "$(GREEN)✅ Production apply cancelled$(NC)"; \
	fi

destroy-prod: ## (TF-PROD) Destroy production environment (DANGEROUS!)
	@echo "$(RED)💣 WARNING: This will DESTROY PRODUCTION!$(NC)"
	@read -p "Type 'DELETE-PRODUCTION' to continue: " -r; \
	if [ "$$REPLY" = "DELETE-PRODUCTION" ]; then \
		cd terraform/environments/prod && terraform destroy; \
	else \
		echo "$(GREEN)✅ Production destroy cancelled$(NC)"; \
	fi

cleanup-prod: ## Clean up production terraform cache
	@echo "$(YELLOW)🧹 Cleaning up production terraform$(NC)"
	@cd terraform/environments/prod && rm -rf .terraform .terraform.lock.hcl

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

# CI/CD deployment workflows
deploy-cicd-local: init-local apply-cluster-local setup-kubectl apply-local ## Full local deployment (CI/CD)
	@echo "$(GREEN)✅ Complete local ML platform deployed$(NC)"

deploy-cicd-dev: init-dev apply-dev ## Full dev deployment (CI/CD)
	@echo "$(GREEN)✅ Complete dev environment deployed$(NC)"

deploy-cicd-staging: init-staging apply-staging ## Full staging deployment (CI/CD)
	@echo "$(GREEN)✅ Complete staging environment deployed$(NC)"

deploy-cicd-prod: init-prod apply-prod ## Full production deployment (CI/CD)
	@echo "$(GREEN)✅ Complete production environment deployed$(NC)"

# Complete local deployment (replaces deploy-local.sh)
deploy-tf-local: ## Complete local ML platform deployment with cleanup
	@echo "$(GREEN)🚀 ML Platform Local Deployment$(NC)"
	@echo "======================================"
	@echo ""
	@echo "📍 Working in: $(shell pwd)"
	@echo ""
	@echo "🧹 Cleaning up existing resources..."
	@$(MAKE) clean-tf-local
	@echo ""
	@echo "✅ Cleanup complete"
	@echo ""
	@echo "🔧 Step 1: Setting up Terraform..."
	@$(MAKE) init-tf-local
	@echo "✅ Terraform provider setup complete"
	@echo ""
	@echo "🐳 Step 2: Creating data platform cluster..."
	@$(MAKE) apply-cluster-tf-local
	@echo ""
	@echo "🔧 Configuring kubectl context..."
	@$(MAKE) setup-kubectl-local
	@echo ""
	# @echo "💾 Step 3: Setting up storage provisioner..."
	# @$(MAKE) setup-storage-local
	@echo ""
	@echo "🔐 Step 4: Deploying security bootstrap (CRDs)..."
	@$(MAKE) deploy-security-bootstrap-tf-local
	@echo ""
	@echo "🏗️  Step 5: Deploying others..."
	@$(MAKE) apply-tf-local
	@echo ""
	@echo "✅ Step 6: Verifying deployment..."
	@kubectl get pods --all-namespaces | grep -E "(postgres|redis|minio|prometheus|grafana)" || true
	@kubectl get pvc --all-namespaces
	@echo ""
	@echo "$(GREEN)🎉 Data Platform deployment completed successfully!$(NC)"
	@echo ""
	@echo "🔗 To access services, use these port-forward commands:"
	@echo "  kubectl port-forward -n database svc/postgres 5432:5432"
	@echo "  kubectl port-forward -n cache svc/redis 6379:6379"
	@echo "  kubectl port-forward -n storage svc/minio 9001:9000"
	@echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
	@echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
	@echo ""
	@echo "🌐 Service endpoints:"
	@echo "  Database: postgresql://admin:password@localhost:5432/metadata"
	@echo "  Cache: redis://localhost:6379"
	@echo "  Storage: http://localhost:9001 (minioadmin/minioadmin)"
	@echo "  Grafana: http://localhost:3000 (admin/admin)"
	@echo "  ArgoCD: https://localhost:8080 (admin/admin123)"
	@echo ""
	@echo "📚 Next: Deploy ArgoCD applications with 'make deploy-argocd-apps'"

# Local development workflow (calls scripts - kept for compatibility)
local-up: deploy-tf-local ## Deploy local platform (full deployment)

deep-clean: ## Deep security cleanup (repository files + infrastructure)
	@echo "$(RED)💣 Running deep security cleanup$(NC)"
	@$(MAKE) tf-clean
	@$(SCRIPTS_DIR)/management/cleanup-infrastructure.sh

# =============================================================================
# Security - Hybrid Infrastructure + GitOps
# =============================================================================
deploy-tf-security-only: ## (TF) Deploy security infrastructure via Terraform only
	@echo "$(BLUE)🔧 Deploying security infrastructure via Terraform$(NC)"
	@cd terraform/environments/local && terraform apply -target=module.security_bootstrap -auto-approve
	@echo "$(GREEN)✅ Security infrastructure deployed$(NC)"

deploy-argocd-security: ## (ArgoCD) Deploy security policies via GitOps
	@echo "$(BLUE)🚀 Deploying security policies via ArgoCD$(NC)"
	@kubectl apply -f kubernetes/security/argocd-security-apps.yaml
	@echo "$(YELLOW)⏳ Waiting for ArgoCD to sync applications...$(NC)"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/network-policies -n argocd || echo "⚠️  Manual sync may be required"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/team-namespaces -n argocd || echo "⚠️  Manual sync may be required"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/security-policies -n argocd || echo "⚠️  Manual sync may be required"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/tls-certificates -n argocd || echo "⚠️  Manual sync may be required"
	@echo "$(GREEN)✅ Security applications setup via ArgoCD$(NC)"

validate-security: ## Validate security configuration
	@echo "$(BLUE)🔍 Validating security configuration$(NC)"
	@$(SCRIPTS_DIR)/security/validate-security.sh

deploy-security-full: terraform-security-bootstrap argocd-deploy-security ## Deploy complete security stack (hybrid)
	@echo "$(GREEN)🎉 Complete security stack deployed!$(NC)"
	@echo ""
	@echo "🔐 Security Features Deployed:"
	@echo "  - Infrastructure: cert-manager, ingress-nginx (Terraform)"
	@echo "  - Policies: NetworkPolicies, TLS certificates (ArgoCD)"
	@echo "  - Validation: Security testing scripts"

deploy-team-isolation: ## Deploy team isolation (quotas, RBAC)
	@echo "$(BLUE)👥 Deploying team isolation$(NC)"
	@$(SCRIPTS_DIR)/security/deploy-single-cluster-isolation.sh

# GitOps and monitoring
# deploy-argocd: ## Deploy ArgoCD for GitOps
# 	@echo "$(BLUE)🚀 Deploying ArgoCD$(NC)"
# 	@$(SCRIPTS_DIR)/deployment/deploy-argocd.sh

deploy-argocd-apps: ## (ArgoCD) Deploy ArgoCD applications
	@echo "$(BLUE)📱 Setting up ArgoCD applications$(NC)"
	@echo "🚀 Deploying base GitOps configuration..."
	@kubectl apply -f kubernetes/base/gitops/argocd-projects.yaml
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/network-policies -n argocd || echo "⚠️  Manual sync may be required"
	@echo "$(GREEN)✅ ArgoCD applications deployed$(NC)"

# Compliance and validation
check-labels: ## Check resource label compliance
	@echo "$(BLUE)🔍 Checking resource label compliance$(NC)"
	@$(SCRIPTS_DIR)/monitoring/check-resource-labels.sh

audit-logs: ## View Kubernetes audit logs
	@echo "$(BLUE)📋 Kubernetes Audit Logs$(NC)"
	@echo "=========================="
	@docker exec data-platform-local-control-plane cat /var/log/kubernetes/audit.log 2>/dev/null | tail -20 || echo "Audit logs not available (cluster may not have audit logging enabled)"

audit-logs-follow: ## Follow Kubernetes audit logs in real-time
	@echo "$(BLUE)📋 Following Kubernetes Audit Logs$(NC)"
	@echo "Press Ctrl+C to stop"
	@docker exec data-platform-local-control-plane tail -f /var/log/kubernetes/audit.log 2>/dev/null || echo "Audit logs not available"

# Development utilities
show-status: ## Show infrastructure status
	@echo "$(BLUE)📊 Infrastructure Status$(NC)"
	@$(SCRIPTS_DIR)/utilities/show-infrastructure.sh

port-forward: ## Setup port forwarding for all services
	@echo "$(BLUE)🔗 Setting up port forwarding$(NC)"
	@echo "Starting port forwards in background..."
	@kubectl port-forward -n database svc/postgres 5432:5432 > /dev/null 2>&1 &
	@kubectl port-forward -n cache svc/redis 6379:6379 > /dev/null 2>&1 &
	@kubectl port-forward -n storage svc/minio 9001:9000 > /dev/null 2>&1 &
	@kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 > /dev/null 2>&1 &
	@echo "$(GREEN)✅ Port forwards started$(NC)"
	@echo "  Database: postgresql://admin:password@localhost:5432/metadata"
	@echo "  Cache: redis://localhost:6379"
	@echo "  Storage: http://localhost:9001 (minioadmin/minioadmin)"
	@echo "  Grafana: http://localhost:3000 (admin/admin)"

kill-port-forward: ## Kill all port forwarding processes
	@echo "$(YELLOW)🛑 Killing port forward processes$(NC)"
	@pkill -f "kubectl port-forward" || true
	@echo "$(GREEN)✅ Port forwards stopped$(NC)"

# Complete platform setup
deploy-platform: deploy-local deploy-security deploy-team-isolation deploy-argocd deploy-monitoring ## Deploy complete platform stack
	@echo "$(GREEN)🎉 Complete ML platform deployed!$(NC)"
	@echo ""
	@echo "$(BLUE)🔗 Access services:$(NC)"
	@echo "  ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &"
	@echo "  Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 > /dev/null 2>&1 &"
	@echo "  MinIO: kubectl port-forward -n storage svc/minio 9001:9000  > /dev/null 2>&1 &"

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
# check-deps: ## Check required dependencies
# 	@echo "$(BLUE)🔍 Checking dependencies$(NC)"
# 	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)❌ terraform not found$(NC)"; exit 1; }
# 	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)❌ kubectl not found$(NC)"; exit 1; }
# 	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ docker not found$(NC)"; exit 1; }
# 	@if command -v tfenv >/dev/null 2>&1; then \
# 		echo "$(GREEN)✅ tfenv installed$(NC)"; \
# 	else \
# 		echo "$(YELLOW)⚠️  tfenv not found (recommended for version management)$(NC)"; \
# 	fi
# 	@echo "$(GREEN)✅ All required dependencies found$(NC)"

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
# CI/CD Specific Targets (for automation)
# =============================================================================

# CI/CD Environment validation
ci-check-deps: check-deps ## CI/CD: Check all dependencies
	@echo "$(BLUE)🔍 CI/CD: Validating environment$(NC)"
	@command -v make >/dev/null 2>&1 || { echo "$(RED)❌ make not found$(NC)"; exit 1; }
	@echo "$(GREEN)✅ CI/CD environment ready$(NC)"

# CI/CD Terraform operations with proper error handling
ci-init-%: ## CI/CD: Initialize environment with validation
	@echo "$(BLUE)🔧 CI/CD: Initializing $* environment$(NC)"
	@cd terraform/environments/$* && \
		rm -f .terraform.lock.hcl && \
		rm -rf .terraform && \
		terraform init --upgrade
	@echo "$(GREEN)✅ CI/CD: $* environment initialized$(NC)"

ci-plan-%: ## CI/CD: Plan with output saving
	@echo "$(BLUE)📋 CI/CD: Planning $* environment$(NC)"
	@cd terraform/environments/$* && \
		terraform plan -out=$*.tfplan
	@echo "$(GREEN)✅ CI/CD: $* plan saved$(NC)"

ci-apply-%: ## CI/CD: Apply with plan validation
	@echo "$(GREEN)🚀 CI/CD: Applying $* environment$(NC)"
	@cd terraform/environments/$* && \
		terraform apply $*.tfplan
	@echo "$(GREEN)✅ CI/CD: $* environment deployed$(NC)"

ci-destroy-%: ## CI/CD: Destroy with confirmation bypass
	@echo "$(RED)💣 CI/CD: Destroying $* environment$(NC)"
	@cd terraform/environments/$* && \
		terraform destroy -auto-approve
	@echo "$(GREEN)✅ CI/CD: $* environment destroyed$(NC)"

# CI/CD Full workflows
ci-deploy-local: ci-check-deps ci-init-local ci-plan-local ci-apply-local ## CI/CD: Complete local deployment
	@echo "$(GREEN)🎉 CI/CD: Local environment deployed$(NC)"

ci-deploy-dev: ci-check-deps ci-init-dev ci-plan-dev ci-apply-dev ## CI/CD: Complete dev deployment
	@echo "$(GREEN)🎉 CI/CD: Dev environment deployed$(NC)"

ci-deploy-staging: ci-check-deps ci-init-staging ci-plan-staging ci-apply-staging ## CI/CD: Complete staging deployment
	@echo "$(GREEN)🎉 CI/CD: Staging environment deployed$(NC)"

ci-deploy-prod: ci-check-deps ci-init-prod ci-plan-prod ci-apply-prod ## CI/CD: Complete production deployment
	@echo "$(GREEN)🎉 CI/CD: Production environment deployed$(NC)"

# CI/CD Testing and validation
ci-test: format validate test ## CI/CD: Run all tests and validation
	@echo "$(GREEN)✅ CI/CD: All tests passed$(NC)"

ci-security-scan: ## CI/CD: Run security scans
	@echo "$(BLUE)🔒 CI/CD: Running security scans$(NC)"
	@cd terraform && \
		tfsec . --format json --out tfsec-results.json || true && \
		checkov -d . --framework terraform --output json --output-file checkov-results.json || true
	@echo "$(GREEN)✅ CI/CD: Security scan completed$(NC)"

# CI/CD Cleanup
ci-cleanup: ## CI/CD: Clean all temporary files
	@echo "$(YELLOW)🧹 CI/CD: Cleaning up$(NC)"
	@find terraform -name "*.tfplan" -delete
	@find terraform -name "*.tfstate.backup" -delete
	@find terraform -name "*-results.json" -delete
	@echo "$(GREEN)✅ CI/CD: Cleanup completed$(NC)"

# =============================================================================
# ArgoCD GitOps Management
# =============================================================================

deploy-argocd-local: ## (ArgoCD) Deploy all ArgoCD applications and setup
	@echo "$(GREEN)🚀 Complete ArgoCD Deployment$(NC)"
	@echo "==============================="
	@echo ""
	@echo "🔐 Step 1: Deploying security policies..."
	@$(MAKE) deploy-argocd-security
	@echo ""
	@echo "📱 Step 2: Deploying ArgoCD applications..."
	@$(MAKE) deploy-argocd-apps
	@echo ""
	@echo "🔄 Step 3: Waiting for applications to sync..."
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/security-policies -n argocd || echo "⚠️  Manual sync may be required"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/network-policies -n argocd || echo "⚠️  Manual sync may be required"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/tls-certificates -n argocd || echo "⚠️  Manual sync may be required"
	@kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/team-namespaces -n argocd || echo "⚠️  Manual sync may be required"
	@echo ""
	@echo "$(GREEN)✅ Complete ArgoCD deployment finished$(NC)"
	@echo ""
	@echo "$(GREEN)🎉 ArgoCD deployment completed!$(NC)"
	@echo ""
	@echo "🔗 Access ArgoCD:"
	@echo "  URL: https://localhost:8080"
	@echo "  Username: admin"
	@echo "  Password: Run 'make argocd-password' to get securely"
	@echo ""
	@echo "📚 Next steps:"
	@echo "  1. Access ArgoCD UI at https://localhost:8080"
	@echo "  2. Get password: make argocd-password"
	@echo "  3. Sync applications: make argocd-sync-all"
	@echo "  4. Check application status: make argocd-status"
	@echo ""
	@echo "💡 Security: Passwords are stored securely in Kubernetes secrets"
	@echo "💡 To stop port forward: pkill -f 'kubectl port-forward'"

argocd-bootstrap: ## Bootstrap ArgoCD for GitOps (ENV=local)
	@echo "$(BLUE)🚀 Bootstrapping ArgoCD for $(ENV) environment$(NC)"
	@$(SCRIPTS_DIR)/management/bootstrap-argocd.sh $(ENV)

argocd-dashboard: ## Open ArgoCD dashboard
	@echo "$(BLUE)📊 Opening ArgoCD dashboard$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh dashboard

argocd-login: ## Login to ArgoCD CLI
	@echo "$(BLUE)🔐 Logging into ArgoCD$(NC)"
	@$(SCRIPTS_DIR)/management/argocd-login.sh

argocd-password: ## Get ArgoCD admin password (secure)
	@echo "$(BLUE)🔑 ArgoCD admin password:$(NC)"
	@$(SCRIPTS_DIR)/management/get-secret.sh argocd_admin_password || echo "Password not found - run 'terraform apply' first"
	@echo ""

get-secret: ## Get any platform secret (Usage: make get-secret SECRET=argocd_admin_password)
	@if [ -z "$(SECRET)" ]; then \
		echo "$(RED)❌ SECRET variable required. Usage: make get-secret SECRET=argocd_admin_password$(NC)"; \
		$(SCRIPTS_DIR)/management/get-secret.sh; \
	else \
		$(SCRIPTS_DIR)/management/get-secret.sh $(SECRET); \
	fi

argocd-apps: ## List all ArgoCD applications
	@echo "$(BLUE)📋 ArgoCD Applications$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh list

argocd-status: ## Show status of all applications
	@echo "$(BLUE)📊 ArgoCD Applications Status$(NC)"
	@$(SCRIPTS_DIR)/argocd-manage.sh apps

argocd-sync-%: ## Sync specific application (e.g., make argocd-sync-data-platform-local)
	@echo "$(GREEN)🔄 Syncing ArgoCD application: $*$(NC)"
	@$(SCRIPTS_DIR)/management/argocd-manage.sh sync $*

argocd-sync-all: ## Sync all ArgoCD applications
	@echo "$(GREEN)🔄 Syncing all ArgoCD applications$(NC)"
	@echo "===================================="
	@argocd app list -o name | while read app; do \
		if [ -n "$$app" ]; then \
			echo "🔄 Syncing $$app..."; \
			argocd app sync $$app || echo "⚠️  Failed to sync $$app"; \
		fi \
	done
	@echo "$(GREEN)✅ All applications synced!$(NC)"

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
	@echo "  $(GREEN)make argocd-sync-data-platform-local$(NC)"
	@echo "  $(GREEN)make argocd-debug-data-platform-prod$(NC)"
