#!/bin/bash
# Graphviz Installation Script for Infrastructure Visualization
# Installs Graphviz (dot command) across different operating systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Graphviz is already installed
check_existing_installation() {
    if command -v dot &> /dev/null; then
        local version=$(dot -V 2>&1 | head -n1)
        log_success "Graphviz is already installed: $version"
        return 0
    else
        log_info "Graphviz not found, proceeding with installation..."
        return 1
    fi
}

# Install Graphviz on macOS
install_macos() {
    log_info "Installing Graphviz on macOS..."
    
    if command -v brew &> /dev/null; then
        log_info "Using Homebrew to install Graphviz..."
        brew install graphviz
    elif command -v port &> /dev/null; then
        log_info "Using MacPorts to install Graphviz..."
        sudo port install graphviz
    else
        log_error "Neither Homebrew nor MacPorts found"
        log_info "Please install Homebrew first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "  Then run: brew install graphviz"
        return 1
    fi
}

# Install Graphviz on Ubuntu/Debian
install_ubuntu() {
    log_info "Installing Graphviz on Ubuntu/Debian..."
    
    # Update package list
    log_info "Updating package list..."
    sudo apt-get update
    
    # Install Graphviz
    log_info "Installing graphviz package..."
    sudo apt-get install -y graphviz
    
    # Install development headers if needed for Python integration
    log_info "Installing development packages for Python integration..."
    sudo apt-get install -y graphviz-dev pkg-config
}

# Install Graphviz on CentOS/RHEL/Fedora
install_redhat() {
    log_info "Installing Graphviz on CentOS/RHEL/Fedora..."
    
    if command -v dnf &> /dev/null; then
        log_info "Using dnf to install Graphviz..."
        sudo dnf install -y graphviz graphviz-devel
    elif command -v yum &> /dev/null; then
        log_info "Using yum to install Graphviz..."
        sudo yum install -y graphviz graphviz-devel
    else
        log_error "Neither dnf nor yum found"
        return 1
    fi
}

# Install Graphviz on Alpine Linux
install_alpine() {
    log_info "Installing Graphviz on Alpine Linux..."
    sudo apk add --no-cache graphviz graphviz-dev
}

# Install Graphviz on Windows (WSL or native)
install_windows() {
    log_info "Installing Graphviz on Windows..."
    
    if command -v choco &> /dev/null; then
        log_info "Using Chocolatey to install Graphviz..."
        choco install graphviz
    elif command -v winget &> /dev/null; then
        log_info "Using winget to install Graphviz..."
        winget install graphviz
    else
        log_warn "No package manager found"
        log_info "Please install Graphviz manually:"
        echo "  1. Download from: https://graphviz.org/download/"
        echo "  2. Add to PATH environment variable"
        echo "  3. Or install Chocolatey and run: choco install graphviz"
        return 1
    fi
}

# Detect operating system and install accordingly
install_graphviz() {
    case "$OSTYPE" in
        darwin*)
            install_macos
            ;;
        linux*)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian)
                        install_ubuntu
                        ;;
                    centos|rhel|fedora)
                        install_redhat
                        ;;
                    alpine)
                        install_alpine
                        ;;
                    *)
                        log_warn "Unsupported Linux distribution: $ID"
                        log_info "Trying Ubuntu/Debian installation method..."
                        install_ubuntu
                        ;;
                esac
            else
                log_warn "Cannot detect Linux distribution"
                log_info "Trying Ubuntu/Debian installation method..."
                install_ubuntu
            fi
            ;;
        msys*|cygwin*|win32*)
            install_windows
            ;;
        *)
            log_error "Unsupported operating system: $OSTYPE"
            log_info "Please install Graphviz manually from: https://graphviz.org/download/"
            return 1
            ;;
    esac
}

# Install Python Graphviz library
install_python_graphviz() {
    log_info "Installing Python Graphviz library..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install --user graphviz
    elif command -v pip &> /dev/null; then
        pip install --user graphviz
    else
        log_warn "pip not found, skipping Python Graphviz library installation"
        log_info "Install manually with: pip3 install graphviz"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying Graphviz installation..."
    
    if command -v dot &> /dev/null; then
        local version=$(dot -V 2>&1 | head -n1)
        log_success "✅ Graphviz installed successfully: $version"
        
        # Test basic functionality
        log_info "Testing basic functionality..."
        echo "digraph G { A -> B; }" | dot -Tpng > /tmp/graphviz_test.png 2>/dev/null
        if [[ $? -eq 0 ]]; then
            log_success "✅ Graphviz dot command working correctly"
            rm -f /tmp/graphviz_test.png
        else
            log_warn "⚠️  Graphviz installed but dot command may not be working properly"
        fi
        
        # Check Python integration
        if python3 -c "import graphviz" &> /dev/null; then
            log_success "✅ Python Graphviz library available"
        else
            log_warn "⚠️  Python Graphviz library not available"
            log_info "Install with: pip3 install --user graphviz"
        fi
        
        return 0
    else
        log_error "❌ Graphviz installation failed"
        return 1
    fi
}

# Show usage instructions
show_usage() {
    echo ""
    log_info "Graphviz Usage for Infrastructure Visualization:"
    echo ""
    echo "🔧 Command Line Usage:"
    echo "  # Generate PNG from Terraform"
    echo "  terraform graph | dot -Tpng > infrastructure.png"
    echo ""
    echo "  # Generate SVG with custom layout"
    echo "  terraform graph | dot -Tsvg -Grankdir=LR > infrastructure.svg"
    echo ""
    echo "🐍 Python Integration:"
    echo "  from graphviz import Digraph"
    echo "  dot = Digraph(comment='Infrastructure')"
    echo "  dot.node('A', 'Database')"
    echo "  dot.node('B', 'API')"
    echo "  dot.edge('A', 'B')"
    echo "  dot.render('infrastructure', format='png')"
    echo ""
    echo "📊 Infrastructure Scripts:"
    echo "  # Use with ML Platform visualization suite"
    echo "  ./scripts/visualization/terraform-visualize.sh"
    echo "  ./scripts/visualization/visualize-infrastructure.sh"
    echo ""
}

# Main execution
main() {
    echo ""
    log_info "🎨 Graphviz Installation for Infrastructure Visualization"
    echo ""
    
    # Check if already installed
    if check_existing_installation; then
        verify_installation
        show_usage
        return 0
    fi
    
    # Install Graphviz system package
    log_info "Installing Graphviz system package..."
    if install_graphviz; then
        log_success "Graphviz system package installed"
    else
        log_error "Failed to install Graphviz system package"
        return 1
    fi
    
    # Install Python library
    log_info "Installing Python Graphviz library..."
    install_python_graphviz
    
    # Verify installation
    verify_installation
    
    # Show usage
    show_usage
    
    echo ""
    log_success "🎉 Graphviz installation complete!"
    log_info "You can now use infrastructure visualization tools that require Graphviz"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi