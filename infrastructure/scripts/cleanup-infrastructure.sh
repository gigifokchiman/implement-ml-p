#!/bin/bash

# Infrastructure Cleanup Script
# Removes temporary files, state files, and other artifacts that shouldn't be committed

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Change to infrastructure directory
cd "$(dirname "$0")/.."

log_info "Starting infrastructure cleanup..."

# Remove Terraform state files (if any)
log_info "Cleaning Terraform state files..."
find . -name "terraform.tfstate*" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.tfstate.backup" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name ".terraform.tfstate.lock.info" -type f -exec rm -f {} \; 2>/dev/null || true

# Remove generated kubeconfig files
log_info "Cleaning kubeconfig files..."
find . -name "*-config" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*kubeconfig*" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.kubeconfig" -type f -exec rm -f {} \; 2>/dev/null || true

# Remove backup files
log_info "Cleaning backup files..."
find . -name "*.backup" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.bak" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.old" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.orig" -type f -exec rm -f {} \; 2>/dev/null || true

# Remove registry backups
log_info "Cleaning registry backup files..."
find . -name "*-registry-backup-*.tar.gz" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "local-registry-backup*.tar.gz" -type f -exec rm -f {} \; 2>/dev/null || true

# Remove temporary files
log_info "Cleaning temporary files..."
find . -name "*.tmp" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.temp" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name ".tmp" -type d -exec rm -rf {} \; 2>/dev/null || true
find . -name "tmp" -type d -exec rm -rf {} \; 2>/dev/null || true

# Remove log files
log_info "Cleaning log files..."
find . -name "*.log" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "logs" -type d -exec rm -rf {} \; 2>/dev/null || true

# Remove editor and IDE files
log_info "Cleaning editor files..."
find . -name "*.swp" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*.swo" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "*~" -type f -exec rm -f {} \; 2>/dev/null || true

# Remove OS files
log_info "Cleaning OS files..."
find . -name ".DS_Store" -type f -exec rm -f {} \; 2>/dev/null || true
find . -name "Thumbs.db" -type f -exec rm -f {} \; 2>/dev/null || true

# Clean empty directories (but preserve structure)
log_info "Cleaning empty directories..."
find . -type d -empty -name "tmp" -exec rmdir {} \; 2>/dev/null || true
find . -type d -empty -name "logs" -exec rmdir {} \; 2>/dev/null || true
find . -type d -empty -name ".tmp" -exec rmdir {} \; 2>/dev/null || true

# Format Terraform files
if command -v terraform >/dev/null 2>&1; then
    log_info "Formatting Terraform files..."
    cd terraform
    terraform fmt -recursive
    cd ..
    log_success "Terraform files formatted"
else
    log_warning "Terraform not found, skipping formatting"
fi

# Validate gitignore coverage
log_info "Checking gitignore coverage..."

# Check for any files that might need to be ignored
potentially_ignored_files=0

# Check for state files
if find . -name "terraform.tfstate*" -type f | grep -q .; then
    log_warning "Found Terraform state files that should be ignored"
    potentially_ignored_files=$((potentially_ignored_files + 1))
fi

# Check for kubeconfig files
if find . -name "*kubeconfig*" -type f | grep -q .; then
    log_warning "Found kubeconfig files that should be ignored"
    potentially_ignored_files=$((potentially_ignored_files + 1))
fi

# Check for sensitive files
if find . -name "*.key" -o -name "*.pem" -o -name "*.crt" | grep -q .; then
    log_warning "Found certificate/key files that should be ignored"
    potentially_ignored_files=$((potentially_ignored_files + 1))
fi

if [ $potentially_ignored_files -eq 0 ]; then
    log_success "No potentially sensitive files found"
else
    log_warning "Found $potentially_ignored_files types of potentially sensitive files"
    log_info "Review .gitignore file to ensure these are properly ignored"
fi

# Report summary
log_success "Infrastructure cleanup completed!"

# Show directory size after cleanup
if command -v du >/dev/null 2>&1; then
    total_size=$(du -sh . 2>/dev/null | cut -f1)
    log_info "Total infrastructure directory size: $total_size"
fi

# Suggest next steps
echo ""
log_info "Suggested next steps:"
echo "  1. Review cleaned files with: git status"
echo "  2. Run infrastructure tests: make test"
echo "  3. Validate Terraform configs: make validate"
echo "  4. Update documentation if needed"

# Check if running in CI/automation
if [ "${CI}" = "true" ] || [ "${GITHUB_ACTIONS}" = "true" ]; then
    log_info "Running in CI environment - cleanup complete"
    exit 0
fi

# Interactive mode - ask if user wants to see status
if [ -t 0 ]; then
    echo ""
    read -p "Would you like to see git status? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git status
    fi
fi