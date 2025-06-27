#!/bin/bash
set -euo pipefail

# Terraform validation and testing script
# Tests all environments for syntax, security, and best practices

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_RESULTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $timestamp - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $timestamp - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message" ;;
    esac
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local environment="$3"
    
    log "INFO" "Running test: $test_name ($environment)"
    
    if eval "$test_command"; then
        log "SUCCESS" "$test_name passed ($environment)"
        TEST_RESULTS+=("✅ $test_name ($environment)")
        return 0
    else
        log "ERROR" "$test_name failed ($environment)"
        TEST_RESULTS+=("❌ $test_name ($environment)")
        return 1
    fi
}

test_terraform_fmt() {
    local env_dir="$1"
    cd "$env_dir"
    terraform fmt -check -recursive
}

test_terraform_validate() {
    local env_dir="$1"
    local env_name="$2"
    cd "$env_dir"
    
    # Set up Docker environment for macOS Docker Desktop if needed
    if [[ "$OSTYPE" == "darwin"* ]] && [[ -S "$HOME/.docker/run/docker.sock" ]]; then
        export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
        log "INFO" "Using Docker Desktop socket: $DOCKER_HOST"
    elif [[ -S "/var/run/docker.sock" ]]; then
        export DOCKER_HOST="unix:///var/run/docker.sock"
        log "INFO" "Using standard Docker socket: $DOCKER_HOST"
    fi
    
    # For local environment, check if Docker is available for Kind provider
    if [[ "$env_name" == "local" ]]; then
        if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
            log "WARN" "Docker not available, skipping Kind provider validation for $env_name"
            return 0  # Skip validation instead of failing
        fi
    fi
    
    terraform init -backend=false
    terraform validate
}

test_terraform_plan() {
    local env_dir="$1"
    local env_name="$2"
    cd "$env_dir"
    
    # Set up Docker environment for macOS Docker Desktop if needed
    if [[ "$OSTYPE" == "darwin"* ]] && [[ -S "$HOME/.docker/run/docker.sock" ]]; then
        export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
        log "INFO" "Using Docker Desktop socket: $DOCKER_HOST"
    elif [[ -S "/var/run/docker.sock" ]]; then
        export DOCKER_HOST="unix:///var/run/docker.sock"
        log "INFO" "Using standard Docker socket: $DOCKER_HOST"
    fi
    
    # Create minimal terraform.tfvars for testing
    if [[ "$env_name" == "local" ]]; then
        # Test local Kind cluster configuration
        cat > terraform.tfvars.test << EOF
cluster_name = "ml-platform-local-test"
registry_port = 5001
EOF
        
        terraform init -backend=false
        terraform plan -var-file=terraform.tfvars.test -out=tfplan
    elif [[ "$env_name" == "dev" ]]; then
        # Test AWS EKS for dev environment
        cat > terraform.tfvars.test << EOF
region = "us-west-2"
cluster_name = "ml-test"
vpc_cidr = "10.0.0.0/16"
EOF
        
        terraform init -backend=false
        terraform plan -var-file=terraform.tfvars.test -out=tfplan
    else
        # Standard test for staging/prod
        cat > terraform.tfvars.test << EOF
region = "us-west-2"
cluster_name = "ml-test"
vpc_cidr = "10.0.0.0/16"
EOF
        
        terraform init -backend=false
        terraform plan -var-file=terraform.tfvars.test -out=tfplan
    fi
    
    # Clean up
    rm -f terraform.tfvars.test tfplan
    rm -rf .terraform
}

test_security_checkov() {
    local env_dir="$1"
    
    # Install checkov if not available
    if ! command -v checkov &> /dev/null; then
        log "WARN" "Checkov not installed, skipping security scan"
        return 0
    fi
    
    cd "$env_dir"
    checkov -f main.tf --framework terraform --check CKV_AWS_79,CKV_AWS_50,CKV_AWS_88 --quiet
}

test_cost_estimation() {
    local env_dir="$1"
    local environment="$2"
    
    # Simple cost check - warn about expensive resources
    cd "$env_dir"
    
    local expensive_instances=(
        "r6g.large" "r6g.xlarge" "r6g.2xlarge"
        "c5.4xlarge" "c5.8xlarge" "c5.12xlarge"
        "m5.4xlarge" "m5.8xlarge" "m5.12xlarge"
        "g4dn.2xlarge" "g4dn.4xlarge" "g4dn.8xlarge"
    )
    
    for instance in "${expensive_instances[@]}"; do
        if grep -q "$instance" main.tf; then
            if [[ "$environment" == "dev" ]]; then
                log "WARN" "Expensive instance type '$instance' found in dev environment"
                return 1
            else
                log "INFO" "Expensive instance type '$instance' found in $environment (acceptable)"
            fi
        fi
    done
    
    return 0
}

test_tagging_compliance() {
    local env_dir="$1"
    cd "$env_dir"
    
    # Check that all resources have required tags
    local required_tags=("Environment" "Project" "ManagedBy")
    
    for tag in "${required_tags[@]}"; do
        if ! grep -q "\"$tag\"" main.tf; then
            log "ERROR" "Required tag '$tag' not found in main.tf"
            return 1
        fi
    done
    
    return 0
}

test_backup_configuration() {
    local env_dir="$1"
    local environment="$2"
    cd "$env_dir"
    
    # Check RDS backup configuration
    if [[ "$environment" == "prod" ]]; then
        if ! grep -q "backup_retention_period.*=.*30" main.tf; then
            log "ERROR" "Production RDS should have 30-day backup retention"
            return 1
        fi
        
        if ! grep -q "deletion_protection.*=.*true" main.tf; then
            log "ERROR" "Production RDS should have deletion protection enabled"
            return 1
        fi
    fi
    
    return 0
}

# Main testing logic
main() {
    log "INFO" "Starting Terraform infrastructure tests"
    
    local environments=("local" "dev" "staging" "prod")
    local failed_tests=0
    
    for env in "${environments[@]}"; do
        local env_dir="$INFRA_DIR/terraform/environments/$env"
        
        if [[ ! -d "$env_dir" ]]; then
            log "WARN" "Environment directory not found: $env_dir"
            continue
        fi
        
        # Check if Docker is available for local Kind testing
        if [[ "$env" == "local" ]]; then
            if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
                log "WARN" "Docker not available, skipping local Kind cluster tests"
                TEST_RESULTS+=("⚠️  terraform fmt (local) - Docker not available")
                TEST_RESULTS+=("⚠️  terraform validate (local) - Docker not available")
                TEST_RESULTS+=("⚠️  terraform plan (local) - Docker not available")
                TEST_RESULTS+=("⚠️  security scan (local) - Docker not available")
                TEST_RESULTS+=("⚠️  cost estimation (local) - Docker not available")
                TEST_RESULTS+=("⚠️  tagging compliance (local) - Docker not available")
                TEST_RESULTS+=("⚠️  backup configuration (local) - Docker not available")
                continue
            fi
        fi
        
        log "INFO" "Testing environment: $env"
        
        # Basic Terraform tests
        run_test "terraform fmt" "test_terraform_fmt '$env_dir'" "$env" || ((failed_tests++))
        run_test "terraform validate" "test_terraform_validate '$env_dir' '$env'" "$env" || ((failed_tests++))
        run_test "terraform plan" "test_terraform_plan '$env_dir' '$env'" "$env" || ((failed_tests++))
        
        # Security and compliance tests
        run_test "security scan" "test_security_checkov '$env_dir'" "$env" || ((failed_tests++))
        run_test "cost estimation" "test_cost_estimation '$env_dir' '$env'" "$env" || ((failed_tests++))
        run_test "tagging compliance" "test_tagging_compliance '$env_dir'" "$env" || ((failed_tests++))
        run_test "backup configuration" "test_backup_configuration '$env_dir' '$env'" "$env" || ((failed_tests++))
        
        echo ""
    done
    
    # Summary
    echo "=========================================="
    echo "Test Results Summary:"
    echo "=========================================="
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        log "SUCCESS" "All Terraform tests passed!"
        exit 0
    else
        log "ERROR" "$failed_tests test(s) failed"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("terraform")
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required dependency '$cmd' not found"
            exit 1
        fi
    done
}

check_dependencies
main "$@"