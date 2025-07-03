#!/bin/bash
# Terraform wrapper script with automatic version management

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-local}
ACTION=${2:-plan}
BASE_DIR=$(dirname "$0")/../terraform/environments

# Usage function
usage() {
    echo -e "${BLUE}Usage: $0 [environment] [action] [additional terraform args]${NC}"
    echo -e "  environment: local, dev, staging, prod (default: local)"
    echo -e "  action: init, plan, apply, destroy, validate, fmt, refresh (default: plan)"
    echo -e ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 local plan                    # Plan local environment"
    echo -e "  $0 local apply                   # Apply local environment"
    echo -e "  $0 prod plan -target=module.database  # Plan specific module in prod"
    echo -e "  $0 dev apply -auto-approve       # Apply dev without confirmation"
    exit 1
}

# Check if environment exists
if [ ! -d "$BASE_DIR/$ENVIRONMENT" ]; then
    echo -e "${RED}❌ Environment '$ENVIRONMENT' does not exist${NC}"
    echo -e "Available environments:"
    ls -1 "$BASE_DIR" | grep -v _shared | sed 's/^/  - /'
    exit 1
fi

# Get Terraform version for environment
TF_VERSION_FILE="$BASE_DIR/$ENVIRONMENT/.terraform-version"
if [ -f "$TF_VERSION_FILE" ]; then
    TF_VERSION=$(cat "$TF_VERSION_FILE")
else
    echo -e "${YELLOW}⚠️  No .terraform-version file found for $ENVIRONMENT${NC}"
    TF_VERSION="1.5.7"  # Default version
fi

echo -e "${BLUE}🔧 Terraform Wrapper${NC}"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Action: ${GREEN}$ACTION${NC}"
echo -e "Terraform Version: ${GREEN}$TF_VERSION${NC}"

# Check if tfenv is available
if command -v tfenv &> /dev/null; then
    echo -e "${BLUE}🔄 Setting Terraform version via tfenv...${NC}"
    tfenv use "$TF_VERSION" || tfenv install "$TF_VERSION"
else
    echo -e "${YELLOW}⚠️  tfenv not found. Using system Terraform.${NC}"
    echo -e "To install tfenv: ${BLUE}brew install tfenv${NC}"
fi

# Verify Terraform version
CURRENT_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4 || echo "unknown")
if [[ "$CURRENT_VERSION" != "$TF_VERSION" ]]; then
    echo -e "${YELLOW}⚠️  Warning: Expected version $TF_VERSION but using $CURRENT_VERSION${NC}"
fi

# Change to environment directory
cd "$BASE_DIR/$ENVIRONMENT"

# Prepare var-file arguments
VAR_FILES=""
if [ -f "../_shared/common.tfvars" ]; then
    VAR_FILES="$VAR_FILES -var-file=../_shared/common.tfvars"
fi
if [ -f "terraform.tfvars" ]; then
    VAR_FILES="$VAR_FILES -var-file=terraform.tfvars"
fi

# Shift the first two arguments (environment and action)
shift 2 2>/dev/null || true

# Execute Terraform command
case $ACTION in
    init)
        echo -e "${GREEN}🚀 Initializing Terraform...${NC}"
        terraform init "$@"
        ;;
    plan)
        echo -e "${GREEN}📋 Planning Terraform changes...${NC}"
        terraform plan $VAR_FILES "$@"
        ;;
    apply)
        echo -e "${GREEN}🚀 Applying Terraform changes...${NC}"
        terraform apply $VAR_FILES "$@"
        ;;
    destroy)
        echo -e "${RED}💣 Destroying Terraform resources...${NC}"
        echo -e "${YELLOW}⚠️  WARNING: This will destroy all resources in $ENVIRONMENT!${NC}"
        read -p "Are you sure? Type 'yes' to continue: " -r
        echo
        if [[ $REPLY == "yes" ]]; then
            terraform destroy $VAR_FILES "$@"
        else
            echo -e "${GREEN}✅ Destruction cancelled${NC}"
        fi
        ;;
    validate)
        echo -e "${GREEN}✅ Validating Terraform configuration...${NC}"
        terraform validate "$@"
        ;;
    fmt)
        echo -e "${GREEN}🎨 Formatting Terraform files...${NC}"
        terraform fmt -recursive "$@"
        ;;
    refresh)
        echo -e "${GREEN}🔄 Refreshing Terraform state...${NC}"
        terraform refresh $VAR_FILES "$@"
        ;;
    output)
        echo -e "${GREEN}📤 Showing Terraform outputs...${NC}"
        terraform output "$@"
        ;;
    state)
        echo -e "${GREEN}📊 Terraform state command...${NC}"
        terraform state "$@"
        ;;
    *)
        echo -e "${RED}❌ Unknown action: $ACTION${NC}"
        usage
        ;;
esac

echo -e "${GREEN}✅ Command completed${NC}"