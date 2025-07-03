#!/bin/bash
# Terraform Infrastructure Visualization Script
# Generates visual diagrams from Terraform configurations using multiple tools

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../docs/diagrams"
TERRAFORM_DIR="${SCRIPT_DIR}/../../terraform"

# Default values
ENVIRONMENT="local"
FORMAT="png"
OPEN_BROWSER=false
USE_ROVER=true
USE_INFRAMAP=false

# Parse command line arguments
usage() {
    echo "Terraform Infrastructure Visualization"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment to visualize (local, dev, staging, prod)"
    echo "  -f, --format FORMAT      Output format (png, svg, pdf, html)"
    echo "  -o, --open               Open generated diagrams in browser"
    echo "  --use-rover              Use Rover for interactive visualization (default)"
    echo "  --use-inframap           Use InfraMap for simplified visualization"
    echo "  --output-dir DIR         Output directory for diagrams"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Visualize local environment with Rover"
    echo "  $0 -e prod -f svg -o     # Visualize production, output SVG, open browser"
    echo "  $0 --use-inframap        # Use InfraMap instead of Rover"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -o|--open)
            OPEN_BROWSER=true
            shift
            ;;
        --use-rover)
            USE_ROVER=true
            USE_INFRAMAP=false
            shift
            ;;
        --use-inframap)
            USE_INFRAMAP=true
            USE_ROVER=false
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
validate_environment() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    if [[ ! -d "$env_dir" ]]; then
        log_error "Environment '$ENVIRONMENT' not found in $env_dir"
        log_info "Available environments:"
        ls -1 "${TERRAFORM_DIR}/environments/" | sed 's/^/  - /'
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for Terraform visualization..."

    local missing_tools=()

    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if ! command -v dot &> /dev/null; then
        missing_tools+=("graphviz (for dot command)")
    fi

    if [[ "$USE_ROVER" == true ]] && ! command -v docker &> /dev/null; then
        missing_tools+=("docker (for Rover)")
    fi

    if [[ "$USE_INFRAMAP" == true ]] && ! command -v inframap &> /dev/null; then
        log_warn "InfraMap not found, will attempt to install via Docker"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install instructions:"
        echo "  - terraform: https://terraform.io/downloads"
        echo "  - graphviz: brew install graphviz (macOS) or apt-get install graphviz (Ubuntu)"
        echo "  - docker: https://docker.com/get-started"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Initialize Terraform
init_terraform() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    log_info "Initializing Terraform for environment: $ENVIRONMENT"
    
    cd "$env_dir"
    
    # Check if already initialized
    if [[ ! -d ".terraform" ]]; then
        log_info "Running terraform init..."
        terraform init -upgrade
    else
        log_info "Terraform already initialized"
    fi
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    log_success "Terraform initialization complete"
}

# Generate basic Terraform graph
generate_terraform_graph() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    local output_file="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-graph.${FORMAT}"
    
    log_info "Generating Terraform dependency graph..."
    
    cd "$env_dir"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    case $FORMAT in
        png|svg|pdf)
            log_info "Generating $FORMAT diagram using Graphviz..."
            terraform graph | dot -T${FORMAT} -o "$output_file"
            ;;
        html)
            log_warn "HTML format not supported for terraform graph, generating PNG instead"
            terraform graph | dot -Tpng -o "${OUTPUT_DIR}/terraform-${ENVIRONMENT}-graph.png"
            output_file="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-graph.png"
            ;;
        *)
            log_error "Unsupported format: $FORMAT"
            exit 1
            ;;
    esac
    
    log_success "Terraform graph generated: $output_file"
    echo "$output_file"
}

# Generate Rover visualization
generate_rover_visualization() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    local output_file="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-rover.html"
    
    log_info "Generating interactive Rover visualization..."
    
    cd "$env_dir"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Check Docker platform compatibility
    local platform_arg=""
    if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
        log_warn "ARM64 platform detected, using platform override for Rover"
        platform_arg="--platform linux/amd64"
    fi
    
    # Try to generate static visualization first
    log_info "Generating static Rover visualization..."
    
    # Create a simple HTML file with Rover-style visualization
    local rover_html="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-rover.html"
    
    # Generate terraform graph data
    local graph_data=$(terraform graph 2>/dev/null || echo "digraph G { Error -> \"Run terraform init first\"; }")
    
    cat > "$rover_html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terraform Infrastructure - ${ENVIRONMENT}</title>
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: #f5f6fa;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            border-radius: 8px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            padding: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 2.5em; font-weight: 300; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .content { padding: 30px; }
        .section { margin: 30px 0; }
        .section h2 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .graph-container { 
            border: 1px solid #ddd; 
            border-radius: 4px; 
            padding: 20px; 
            background: #fafafa; 
            overflow-x: auto;
        }
        .graph-data { 
            font-family: 'Monaco', 'Menlo', monospace; 
            font-size: 12px; 
            white-space: pre-wrap; 
            background: #2c3e50; 
            color: #ecf0f1; 
            padding: 15px; 
            border-radius: 4px;
            overflow-x: auto;
        }
        .interactive-note {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px;
            margin: 20px 0;
            border-radius: 0 4px 4px 0;
        }
        .stats { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin: 20px 0;
        }
        .stat-card { 
            background: white; 
            border: 1px solid #ddd; 
            border-radius: 4px; 
            padding: 20px; 
            text-align: center;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .stat-number { font-size: 2em; font-weight: bold; color: #3498db; }
        .stat-label { color: #7f8c8d; margin-top: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Terraform Infrastructure</h1>
            <p>Environment: ${ENVIRONMENT} | Generated: $(date)</p>
        </div>
        
        <div class="content">
            <div class="section">
                <h2>📊 Infrastructure Overview</h2>
                <div class="interactive-note">
                    <strong>Note:</strong> This is a static visualization. For full interactive Rover experience, 
                    run the Docker container manually with ARM64 compatibility or on an AMD64 system.
                </div>
                
                <div class="stats">
                    <div class="stat-card">
                        <div class="stat-number">$(echo "$graph_data" | grep -o '\->' | wc -l | tr -d ' ')</div>
                        <div class="stat-label">Dependencies</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-number">$(echo "$graph_data" | grep -o '[a-zA-Z_][a-zA-Z0-9_]*\.' | sort -u | wc -l | tr -d ' ')</div>
                        <div class="stat-label">Resources</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-number">${ENVIRONMENT}</div>
                        <div class="stat-label">Environment</div>
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2>🔗 Resource Dependencies (Graph Data)</h2>
                <div class="graph-container">
                    <div class="graph-data">$graph_data</div>
                </div>
            </div>
            
            <div class="section">
                <h2>🐳 Interactive Rover Setup</h2>
                <p>To run the full interactive Rover visualization:</p>
                <div class="graph-container">
                    <pre><code># For ARM64 systems (Apple Silicon)
docker run --rm --platform linux/amd64 \\
  -v "\$(pwd):/src" \\
  -p 9000:9000 \\
  im2nguyen/rover \\
  -tfPath /src

# For AMD64 systems  
docker run --rm \\
  -v "\$(pwd):/src" \\
  -p 9000:9000 \\
  im2nguyen/rover \\
  -tfPath /src

# Then open: http://localhost:9000</code></pre>
                </div>
            </div>
            
            <div class="section">
                <h2>📋 Alternative Visualization Tools</h2>
                <p>Use these commands for additional visualization options:</p>
                <div class="graph-container">
                    <pre><code># Generate PNG with Graphviz
terraform graph | dot -Tpng > infrastructure.png

# Generate SVG with custom layout
terraform graph | dot -Tsvg -Grankdir=LR > infrastructure.svg

# Use InfraMap for simplified view
inframap generate --format png .</code></pre>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "Static Rover-style visualization generated: $rover_html"
    
    # Try to run actual Rover if Docker is available and user wants interactive mode
    if [[ "$OPEN_BROWSER" == true ]] && command -v docker &> /dev/null; then
        log_info "Attempting to start interactive Rover server..."
        
        # Run Rover in background with proper flags
        timeout 10s docker run --rm $platform_arg \
            -v "$(pwd):/src" \
            -p 9000:9000 \
            im2nguyen/rover \
            -tfPath /src > /dev/null 2>&1 &
        
        local rover_pid=$!
        
        # Give Rover time to start
        sleep 3
        
        # Check if Rover is responding
        if curl -s http://localhost:9000 > /dev/null 2>&1; then
            log_success "Interactive Rover available at: http://localhost:9000"
            log_info "Press Ctrl+C to stop the Rover server when done"
        else
            # Kill the background process if it's not working
            kill $rover_pid 2>/dev/null || true
            log_warn "Interactive Rover failed to start"
            
            # Fallback to enhanced graph visualization
            log_info "Using enhanced graph visualization as fallback..."
            local enhanced_script="${SCRIPT_DIR}/terraform-graph-enhanced.sh"
            if [[ -x "$enhanced_script" ]]; then
                "$enhanced_script" -e "$ENVIRONMENT" -f "$FORMAT" --output-dir "$(dirname "$rover_html")"
                log_success "Enhanced graph visualization generated as alternative"
            fi
        fi
    fi
    
    echo "$rover_html"
}

# Generate InfraMap visualization
generate_inframap_visualization() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    local output_file="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-inframap.${FORMAT}"
    
    log_info "Generating InfraMap visualization..."
    
    cd "$env_dir"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Check if InfraMap is available locally
    if command -v inframap &> /dev/null; then
        log_info "Using local InfraMap installation..."
        case $FORMAT in
            png|svg)
                inframap generate --output "$output_file" --format "$FORMAT" .
                ;;
            html)
                inframap generate --output "${OUTPUT_DIR}/terraform-${ENVIRONMENT}-inframap.html" --format html .
                output_file="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-inframap.html"
                ;;
            *)
                log_error "InfraMap doesn't support format: $FORMAT"
                return 1
                ;;
        esac
    else
        log_info "Using InfraMap via Docker..."
        docker run --rm \
            -v "$(pwd):/workspace" \
            -v "$OUTPUT_DIR:/output" \
            cyclonedx/inframap:latest \
            generate --output "/output/terraform-${ENVIRONMENT}-inframap.${FORMAT}" --format "$FORMAT" /workspace
    fi
    
    if [[ -f "$output_file" ]]; then
        log_success "InfraMap visualization generated: $output_file"
        echo "$output_file"
    else
        log_error "Failed to generate InfraMap visualization"
        return 1
    fi
}

# Generate comprehensive documentation
generate_documentation() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    local doc_file="${OUTPUT_DIR}/terraform-${ENVIRONMENT}-docs.md"
    
    log_info "Generating Terraform documentation..."
    
    cd "$env_dir"
    
    cat > "$doc_file" << EOF
# Terraform Infrastructure Documentation - ${ENVIRONMENT}

**Generated:** $(date)
**Environment:** ${ENVIRONMENT}
**Terraform Version:** $(terraform version -json | jq -r '.terraform_version')

## Architecture Overview

This document provides an overview of the Terraform infrastructure for the **${ENVIRONMENT}** environment.

## Resource Summary

### Providers
\`\`\`
$(terraform providers 2>/dev/null || echo "Run terraform init to see providers")
\`\`\`

### Outputs
\`\`\`
$(terraform output 2>/dev/null || echo "No outputs available - run terraform apply first")
\`\`\`

## Resource Dependencies

The infrastructure dependencies are visualized in the accompanying diagram files:

- **Basic Graph:** terraform-${ENVIRONMENT}-graph.${FORMAT}
$(if [[ "$USE_ROVER" == true ]]; then
    echo "- **Interactive Rover:** terraform-${ENVIRONMENT}-rover.html"
fi)
$(if [[ "$USE_INFRAMAP" == true ]]; then
    echo "- **InfraMap:** terraform-${ENVIRONMENT}-inframap.${FORMAT}"
fi)

## Security Considerations

### Network Security
- VPC with private subnets for sensitive resources
- Security groups with principle of least privilege
- NAT gateways for outbound internet access

### Data Security
- Encryption at rest for all storage
- Encryption in transit using TLS
- Backup strategies for critical data

### Access Control
- IAM roles with minimal required permissions
- Regular rotation of access keys
- Multi-factor authentication required

## Monitoring and Observability

- CloudWatch for AWS resources
- Prometheus for Kubernetes metrics
- Grafana for visualization
- Jaeger for distributed tracing

---

**Note:** This documentation is auto-generated. For the latest information, refer to the Terraform configuration files.
EOF

    log_success "Documentation generated: $doc_file"
    echo "$doc_file"
}

# Open files in browser/viewer
open_files() {
    local files=("$@")
    
    if [[ "$OPEN_BROWSER" == true ]]; then
        log_info "Opening generated files..."
        
        for file in "${files[@]}"; do
            if [[ -f "$file" ]]; then
                case "$OSTYPE" in
                    darwin*)  # macOS
                        open "$file"
                        ;;
                    linux*)   # Linux
                        xdg-open "$file" 2>/dev/null || true
                        ;;
                    msys*)    # Windows (Git Bash)
                        start "$file"
                        ;;
                    *)
                        log_warn "Cannot auto-open files on this platform"
                        ;;
                esac
            fi
        done
    fi
}

# Main execution
main() {
    log_info "Starting Terraform visualization for environment: $ENVIRONMENT"
    
    validate_environment
    check_prerequisites
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    init_terraform
    
    local generated_files=()
    
    # Generate basic Terraform graph
    log_info "Generating basic Terraform dependency graph..."
    if graph_file=$(generate_terraform_graph); then
        generated_files+=("$graph_file")
    fi
    
    # Generate Rover visualization if requested
    if [[ "$USE_ROVER" == true ]]; then
        log_info "Generating interactive Rover visualization..."
        if rover_file=$(generate_rover_visualization); then
            generated_files+=("$rover_file")
        fi
    fi
    
    # Generate InfraMap visualization if requested
    if [[ "$USE_INFRAMAP" == true ]]; then
        log_info "Generating InfraMap visualization..."
        if inframap_file=$(generate_inframap_visualization); then
            generated_files+=("$inframap_file")
        fi
    fi
    
    # Generate documentation
    if doc_file=$(generate_documentation); then
        generated_files+=("$doc_file")
    fi
    
    # Display results
    echo ""
    log_success "Terraform visualization complete!"
    echo "Generated files:"
    for file in "${generated_files[@]}"; do
        echo "  📄 $file"
    done
    
    echo ""
    log_info "Output directory: $OUTPUT_DIR"
    
    # Open files if requested
    open_files "${generated_files[@]}"
    
    echo ""
    log_info "Next steps:"
    echo "  1. Review the generated diagrams to understand infrastructure dependencies"
    echo "  2. Share documentation with your team for architecture reviews"
    echo "  3. Update diagrams when infrastructure changes"
    echo "  4. Consider setting up automated diagram generation in CI/CD"
}

# Execute main function
main "$@"