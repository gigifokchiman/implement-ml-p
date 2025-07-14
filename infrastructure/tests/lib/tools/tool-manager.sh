#!/bin/bash
# Tool installation and management for infrastructure testing
# Handles installation, version checking, and tool availability

# Guard against multiple sourcing
if [[ -n "${_TOOL_MANAGER_SH_LOADED:-}" ]]; then
    return 0
fi
_TOOL_MANAGER_SH_LOADED=1

set -euo pipefail

# Source common utilities
TOOL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOL_SCRIPT_DIR/../utils/common.sh"

# Tool versions - using simple functions for compatibility
get_tool_version() {
    local tool="$1"
    case "$tool" in
        "terraform") echo "1.6.0" ;;
        "checkov") echo "latest" ;;
        "opa") echo "0.57.0" ;;
        "kubeconform") echo "0.6.3" ;;
        "trivy") echo "latest" ;;
        "k6") echo "latest" ;;
        *) echo "latest" ;;
    esac
}

# Tool installation commands - using functions for compatibility
get_install_command() {
    local tool="$1"
    case "$tool" in
        "terraform") echo "echo 'Please install Terraform manually from https://terraform.io'" ;;
        "checkov") echo "pip3 install checkov" ;;
        "opa") echo "brew install opa || curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.57.0/opa_linux_amd64 && chmod +x opa && sudo mv opa /usr/local/bin/" ;;
        "kubeconform") echo "brew install kubeconform || curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz && sudo mv kubeconform /usr/local/bin/" ;;
        "trivy") echo "brew install trivy || curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin" ;;
        "k6") echo "brew install k6 || curl https://github.com/grafana/k6/releases/download/v0.46.0/k6-v0.46.0-linux-amd64.tar.gz -L | tar xvz --strip-components 1" ;;
        "kubectl") echo "echo 'Please install kubectl manually'" ;;
        "kustomize") echo "brew install kustomize || curl -L https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_linux_amd64.tar.gz | tar xz && sudo mv kustomize /usr/local/bin/" ;;
        "jq") echo "brew install jq || sudo apt-get install jq" ;;
        *) echo "echo 'No installation command available for $tool'" ;;
    esac
}

# Check if tool is installed with correct version
check_tool_version() {
    local tool="$1"
    local required_version
    required_version=$(get_tool_version "$tool")
    
    if ! command_exists "$tool"; then
        return 1
    fi
    
    # For "latest" version, just check if tool exists
    if [[ "$required_version" == "latest" ]]; then
        return 0
    fi
    
    # Version-specific checks
    case "$tool" in
        "terraform")
            local current_version
            current_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
            [[ "$current_version" == "$required_version" ]]
            ;;
        "opa")
            local current_version
            current_version=$(opa version 2>/dev/null | grep Version | cut -d' ' -f2 | sed 's/v//' || echo "unknown")
            [[ "$current_version" == "$required_version" ]]
            ;;
        *)
            # For other tools, just check if they exist
            return 0
            ;;
    esac
}

# Install a specific tool
install_tool() {
    local tool="$1"
    local install_cmd
    install_cmd=$(get_install_command "$tool")
    
    if [[ -z "$install_cmd" ]]; then
        print_error "No installation command defined for $tool"
        return 1
    fi
    
    print_info "Installing $tool..."
    if eval "$install_cmd"; then
        print_success "$tool installed successfully"
    else
        print_error "Failed to install $tool"
        return 1
    fi
}

# Ensure tool is available and install if needed
ensure_tool_available() {
    local tool="$1"
    local required="${2:-true}"
    
    if check_tool_version "$tool"; then
        print_info "$tool is available"
        return 0
    fi
    
    if [[ "$required" == "false" ]]; then
        print_warning "$tool is not available (optional)"
        return 0
    fi
    
    print_warning "$tool is not available, attempting to install..."
    install_tool "$tool"
}

# Install core testing tools
install_core_tools() {
    print_header "Installing Core Testing Tools"
    
    local core_tools=("terraform" "kubectl" "kustomize" "jq")
    local failed_tools=()
    
    for tool in "${core_tools[@]}"; do
        if ! ensure_tool_available "$tool"; then
            failed_tools+=("$tool")
        fi
    done
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        print_error "Failed to install core tools: ${failed_tools[*]}"
        return 1
    fi
    
    print_success "All core tools installed"
}

# Install security testing tools
install_security_tools() {
    print_header "Installing Security Testing Tools"
    
    local security_tools=("checkov" "trivy")
    local failed_tools=()
    
    for tool in "${security_tools[@]}"; do
        if ! ensure_tool_available "$tool"; then
            failed_tools+=("$tool")
        fi
    done
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        print_error "Failed to install security tools: ${failed_tools[*]}"
        return 1
    fi
    
    print_success "All security tools installed"
}

# Install kubernetes testing tools
install_kubernetes_tools() {
    print_header "Installing Kubernetes Testing Tools"
    
    local k8s_tools=("kubeconform" "opa")
    local failed_tools=()
    
    for tool in "${k8s_tools[@]}"; do
        if ! ensure_tool_available "$tool"; then
            failed_tools+=("$tool")
        fi
    done
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        print_error "Failed to install Kubernetes tools: ${failed_tools[*]}"
        return 1
    fi
    
    print_success "All Kubernetes tools installed"
}

# Install performance testing tools
install_performance_tools() {
    print_header "Installing Performance Testing Tools"
    
    local perf_tools=("k6")
    local failed_tools=()
    
    for tool in "${perf_tools[@]}"; do
        if ! ensure_tool_available "$tool" "false"; then
            failed_tools+=("$tool")
        fi
    done
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        print_warning "Some performance tools not available: ${failed_tools[*]}"
    else
        print_success "All performance tools installed"
    fi
}

# Install all tools
install_all_tools() {
    print_header "Installing All Testing Tools"
    
    install_core_tools
    install_security_tools
    install_kubernetes_tools
    install_performance_tools
    
    print_success "Tool installation completed"
}

# Check status of all tools
check_tool_status() {
    print_header "Tool Status Check"
    
    local all_tools=("terraform" "kubectl" "kustomize" "jq" "checkov" "trivy" "kubeconform" "opa" "k6")
    local available_tools=()
    local missing_tools=()
    
    for tool in "${all_tools[@]}"; do
        if command_exists "$tool"; then
            available_tools+=("$tool")
            print_success "$tool - available"
        else
            missing_tools+=("$tool")
            print_error "$tool - missing"
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "Available: ${#available_tools[@]}/${#all_tools[@]} tools"
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "Missing tools: ${missing_tools[*]}"
        echo ""
        echo "To install missing tools, run:"
        echo "  make install-all-tools"
        return 1
    else
        print_success "All tools are available"
        return 0
    fi
}

# Generate tool installation script
generate_install_script() {
    local output_file="${1:-install-tools.sh}"
    
    cat > "$output_file" << 'EOF'
#!/bin/bash
# Auto-generated tool installation script

set -euo pipefail

# Install core tools
install_core() {
    echo "Installing core tools..."
    
    # Terraform
    if ! command -v terraform >/dev/null; then
        echo "Please install Terraform manually from https://terraform.io"
    fi
    
    # kubectl
    if ! command -v kubectl >/dev/null; then
        echo "Please install kubectl manually"
    fi
    
    # kustomize
    if ! command -v kustomize >/dev/null; then
        if command -v brew >/dev/null; then
            brew install kustomize
        else
            curl -L https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_linux_amd64.tar.gz | tar xz
            sudo mv kustomize /usr/local/bin/
        fi
    fi
    
    # jq
    if ! command -v jq >/dev/null; then
        if command -v brew >/dev/null; then
            brew install jq
        else
            sudo apt-get install jq
        fi
    fi
}

# Install security tools
install_security() {
    echo "Installing security tools..."
    
    
    # checkov
    if ! command -v checkov >/dev/null; then
        pip3 install checkov
    fi
    
    # trivy
    if ! command -v trivy >/dev/null; then
        if command -v brew >/dev/null; then
            brew install trivy
        else
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        fi
    fi
}

# Install Kubernetes tools
install_kubernetes() {
    echo "Installing Kubernetes tools..."
    
    # kubeconform
    if ! command -v kubeconform >/dev/null; then
        if command -v brew >/dev/null; then
            brew install kubeconform
        else
            curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
            sudo mv kubeconform /usr/local/bin/
        fi
    fi
    
    # opa
    if ! command -v opa >/dev/null; then
        if command -v brew >/dev/null; then
            brew install opa
        else
            curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.57.0/opa_linux_amd64
            chmod +x opa && sudo mv opa /usr/local/bin/
        fi
    fi
}

# Install performance tools
install_performance() {
    echo "Installing performance tools..."
    
    # k6
    if ! command -v k6 >/dev/null; then
        if command -v brew >/dev/null; then
            brew install k6
        else
            curl https://github.com/grafana/k6/releases/download/v0.46.0/k6-v0.46.0-linux-amd64.tar.gz -L | tar xvz --strip-components 1
            sudo mv k6 /usr/local/bin/
        fi
    fi
}

# Main installation
main() {
    install_core
    install_security
    install_kubernetes
    install_performance
    
    echo "Tool installation completed!"
}

main "$@"
EOF

    chmod +x "$output_file"
    print_success "Installation script generated: $output_file"
}

# Main function for CLI usage
main() {
    case "${1:-status}" in
        "status")
            check_tool_status
            ;;
        "install-core")
            install_core_tools
            ;;
        "install-security")
            install_security_tools
            ;;
        "install-kubernetes")
            install_kubernetes_tools
            ;;
        "install-performance")
            install_performance_tools
            ;;
        "install-all")
            install_all_tools
            ;;
        "generate-script")
            generate_install_script "${2:-install-tools.sh}"
            ;;
        *)
            echo "Usage: $0 {status|install-core|install-security|install-kubernetes|install-performance|install-all|generate-script}"
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi