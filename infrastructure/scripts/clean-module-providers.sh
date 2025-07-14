#!/bin/bash

# Enterprise Provider Version Management - Module Cleanup
# Removes provider version constraints from modules to enable centralized version control
# Based on Netflix, Airbnb, Spotify best practices

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/../terraform/modules"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Cleaning module provider constraints for enterprise version management...${NC}"

# Function to clean a single file
clean_terraform_file() {
    local file="$1"
    local backup_file="${file}.backup"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    # Create backup
    cp "$file" "$backup_file"
    
    # Remove terraform blocks with required_providers from modules
    # Keep only version requirements, remove the constraints
    awk '
    BEGIN { 
        in_terraform_block = 0
        in_required_providers = 0
        terraform_indent = 0
        providers_indent = 0
        skip_block = 0
    }
    
    # Detect terraform block start
    /^[[:space:]]*terraform[[:space:]]*{/ {
        in_terraform_block = 1
        terraform_indent = length($0) - length(ltrim($0))
        skip_block = 1
        next
    }
    
    # Handle terraform block content
    in_terraform_block == 1 {
        current_indent = length($0) - length(ltrim($0))
        
        # Detect required_providers block
        if (/required_providers[[:space:]]*{/) {
            in_required_providers = 1
            providers_indent = current_indent
            next
        }
        
        # Skip required_providers content
        if (in_required_providers == 1) {
            if (current_indent <= providers_indent && /}/) {
                in_required_providers = 0
                next
            }
            if (in_required_providers == 1) {
                next
            }
        }
        
        # End of terraform block
        if (current_indent <= terraform_indent && /}/) {
            in_terraform_block = 0
            skip_block = 0
            next
        }
        
        # Keep required_version lines
        if (/required_version/) {
            print
            next
        }
        
        # Skip other terraform block content
        if (skip_block == 1) {
            next
        }
    }
    
    # Print all other lines
    in_terraform_block == 0 { print }
    
    function ltrim(str) {
        gsub(/^[[:space:]]+/, "", str)
        return str
    }
    ' "$file" > "${file}.tmp"
    
    # Replace original with cleaned version
    mv "${file}.tmp" "$file"
    
    # Check if file was actually modified
    if ! diff -q "$file" "$backup_file" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Cleaned: ${file}${NC}"
        rm "$backup_file"
        return 0
    else
        # No changes, restore original
        mv "$backup_file" "$file"
        return 1
    fi
}

# Find and clean all terraform files in modules
echo -e "${BLUE}ℹ️  Scanning modules for provider constraints...${NC}"

cleaned_count=0
total_count=0

# Process all .tf files in modules directory
while IFS= read -r -d '' file; do
    ((total_count++))
    if clean_terraform_file "$file"; then
        ((cleaned_count++))
    fi
done < <(find "$MODULES_DIR" -name "*.tf" -type f -print0)

echo -e "${BLUE}ℹ️  Processing summary:${NC}"
echo -e "  Total files processed: $total_count"
echo -e "  Files cleaned: $cleaned_count"

# Clean up any remaining provider version references in variables and outputs
echo -e "${BLUE}ℹ️  Cleaning provider version variables...${NC}"

# Remove provider version variables that are no longer needed
find "$MODULES_DIR" -name "variables.tf" -type f -exec sed -i '' '
/variable.*provider.*version/,/^}$/d
/variable.*aws_version/,/^}$/d
/variable.*kubernetes_version.*{/,/^}$/d
/variable.*helm_version/,/^}$/d
' {} \;

echo -e "${GREEN}✅ Module provider constraint cleanup completed${NC}"
echo -e "${YELLOW}⚠️  Note: Modules now inherit provider versions from root configuration${NC}"
echo -e "${BLUE}ℹ️  This follows enterprise patterns used by Netflix, Airbnb, and Spotify${NC}"