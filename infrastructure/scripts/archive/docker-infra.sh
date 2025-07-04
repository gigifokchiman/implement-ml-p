#!/bin/bash

# Docker Infrastructure Management Script
# Provides convenient commands for managing infrastructure with Docker

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE="ml-platform/infra-tools"
DOCKER_TAG="latest"
CONTAINER_NAME="ml-platform-infra-tools"
COMPOSE_FILE="docker-compose.infra.yml"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Check if container is running
is_container_running() {
    docker ps -q -f name=$CONTAINER_NAME | grep -q .
}

# Build the infrastructure tools image
build_image() {
    log_info "Building infrastructure tools Docker image..."
    docker build -t $DOCKER_IMAGE:$DOCKER_TAG .
    log_success "Docker image built successfully"
}

# Start the container
start_container() {
    if is_container_running; then
        log_warning "Container is already running"
        return 0
    fi
    
    log_info "Starting infrastructure tools container..."
    docker-compose -f $COMPOSE_FILE up -d infra-tools
    
    # Wait for container to be healthy
    log_info "Waiting for container to be ready..."
    sleep 3
    
    if is_container_running; then
        log_success "Container started successfully"
    else
        log_error "Failed to start container"
        exit 1
    fi
}

# Stop the container
stop_container() {
    if ! is_container_running; then
        log_warning "Container is not running"
        return 0
    fi
    
    log_info "Stopping infrastructure tools container..."
    docker-compose -f $COMPOSE_FILE down
    log_success "Container stopped"
}

# Open shell in container
open_shell() {
    if ! is_container_running; then
        log_warning "Container not running. Starting it first..."
        start_container
    fi
    
    log_info "Opening shell in infrastructure tools container..."
    docker exec -it $CONTAINER_NAME /bin/bash
}

# Execute command in container
exec_command() {
    if ! is_container_running; then
        log_error "Container is not running. Start it first with: $0 start"
        exit 1
    fi
    
    local cmd="$*"
    log_info "Executing: $cmd"
    docker exec -it $CONTAINER_NAME bash -c "$cmd"
}

# Run Terraform command
terraform_cmd() {
    local env=$1
    local action=$2
    shift 2
    local args="$*"
    
    if [[ ! "$env" =~ ^(local|dev|staging|prod)$ ]]; then
        log_error "Invalid environment. Use: local, dev, staging, or prod"
        exit 1
    fi
    
    local tf_cmd="cd terraform/environments/$env && terraform $action $args"
    
    if [[ "$action" == "apply" && "$env" == "prod" ]]; then
        log_warning "You are about to apply changes to PRODUCTION!"
        read -p "Are you sure? Type 'yes' to continue: " -r
        if [[ ! $REPLY == "yes" ]]; then
            log_success "Production apply cancelled"
            return 0
        fi
    fi
    
    exec_command "$tf_cmd"
}

# Run security scan
security_scan() {
    log_info "Running security scans..."
    exec_command "cd terraform && checkov -d . --framework terraform"
    exec_command "cd terraform && tfsec ."
    log_success "Security scans completed"
}

# Health check
health_check() {
    if ! is_container_running; then
        log_error "Container is not running"
        exit 1
    fi
    
    log_info "Running health check..."
    exec_command "/usr/local/bin/health-check.sh"
}

# Show logs
show_logs() {
    log_info "Showing container logs..."
    docker-compose -f $COMPOSE_FILE logs -f infra-tools
}

# Clean up Docker resources
clean_docker() {
    log_warning "Cleaning up Docker infrastructure..."
    docker-compose -f $COMPOSE_FILE down --volumes --rmi all 2>/dev/null || true
    docker system prune -f
    log_success "Docker cleanup completed"
}

# Show status
show_status() {
    echo -e "${BLUE}🐳 Docker Infrastructure Status${NC}"
    echo ""
    
    # Docker status
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}Docker: Running${NC}"
    else
        echo -e "${RED}Docker: Not running${NC}"
    fi
    
    # Container status
    if is_container_running; then
        echo -e "${GREEN}Container: Running${NC}"
        
        # Get container info
        local created=$(docker inspect $CONTAINER_NAME --format '{{.Created}}' | cut -d'T' -f1)
        local status=$(docker inspect $CONTAINER_NAME --format '{{.State.Status}}')
        echo "  Created: $created"
        echo "  Status: $status"
        
        # Health check
        if docker exec $CONTAINER_NAME /usr/local/bin/health-check.sh >/dev/null 2>&1; then
            echo -e "  Health: ${GREEN}Healthy${NC}"
        else
            echo -e "  Health: ${RED}Unhealthy${NC}"
        fi
    else
        echo -e "${YELLOW}Container: Not running${NC}"
    fi
    
    # Image status
    if docker images $DOCKER_IMAGE:$DOCKER_TAG --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | grep -q $DOCKER_TAG; then
        echo -e "${GREEN}Image: Available${NC}"
        docker images $DOCKER_IMAGE:$DOCKER_TAG --format "  Size: {{.Size}}, Created: {{.CreatedAt}}"
    else
        echo -e "${YELLOW}Image: Not built${NC}"
    fi
}

# Show help
show_help() {
    cat << EOF
🐳 Docker Infrastructure Management Script

Usage: $0 <command> [options]

Commands:
  build                     Build the infrastructure tools Docker image
  start                     Start the infrastructure container
  stop                      Stop the infrastructure container
  shell                     Open shell in the container
  exec <command>            Execute command in container
  
  # Terraform commands
  tf <env> <action> [args]  Run Terraform command
                           env: local|dev|staging|prod
                           action: init|plan|apply|destroy
  
  # Utility commands
  scan                      Run security scans
  health                    Check container health
  logs                      Show container logs
  status                    Show infrastructure status
  clean                     Clean up Docker resources
  
  help                      Show this help

Examples:
  $0 build                  # Build the infrastructure image
  $0 start                  # Start the container
  $0 shell                  # Open shell in container
  $0 tf local init          # Initialize local environment
  $0 tf local plan          # Plan local changes
  $0 tf local apply         # Apply local changes
  $0 exec "kubectl get pods" # Run kubectl command
  $0 scan                   # Run security scans
  $0 status                 # Show status

Environment Variables:
  DOCKER_IMAGE             Docker image name (default: $DOCKER_IMAGE)
  DOCKER_TAG               Docker image tag (default: $DOCKER_TAG)
  CONTAINER_NAME           Container name (default: $CONTAINER_NAME)
  COMPOSE_FILE             Docker compose file (default: $COMPOSE_FILE)

EOF
}

# Main command dispatcher
main() {
    check_docker
    
    case ${1:-help} in
        build)
            build_image
            ;;
        start)
            start_container
            ;;
        stop)
            stop_container
            ;;
        shell)
            open_shell
            ;;
        exec)
            shift
            exec_command "$@"
            ;;
        tf)
            shift
            terraform_cmd "$@"
            ;;
        scan)
            security_scan
            ;;
        health)
            health_check
            ;;
        logs)
            show_logs
            ;;
        status)
            show_status
            ;;
        clean)
            clean_docker
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"