#!/bin/bash
# Unified Infrastructure Visualization Script
# Generates comprehensive visual diagrams from both Terraform and Kubernetes configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../docs/diagrams"

# Default values
ENVIRONMENT="local"
FORMAT="png"
OPEN_BROWSER=false
TERRAFORM_ONLY=false
KUBERNETES_ONLY=false
FULL_SUITE=true
CLEANUP_AFTER=false

# Parse command line arguments
usage() {
    cat << EOF
Infrastructure Visualization Suite

Generates comprehensive visual documentation for ML Platform infrastructure
using multiple visualization tools for both Terraform and Kubernetes.

Usage: $0 [OPTIONS]

OPTIONS:
  -e, --environment ENV      Environment to visualize (local, dev, staging, prod)
  -f, --format FORMAT        Output format (png, svg, pdf, html)
  -o, --open                 Open generated diagrams in browser
  --terraform-only           Only generate Terraform visualizations
  --kubernetes-only          Only generate Kubernetes visualizations
  --cleanup                  Remove temporary files after generation
  --output-dir DIR           Output directory for diagrams
  --help, -h                Show this help message

EXAMPLES:
  $0                         # Generate all diagrams for local environment
  $0 -e prod -f svg -o       # Production diagrams as SVG, open in browser
  $0 --terraform-only        # Only Terraform infrastructure diagrams
  $0 --kubernetes-only       # Only Kubernetes application diagrams

GENERATED OUTPUTS:
  📊 Terraform Infrastructure:
    - Dependency graphs (GraphViz)
    - Interactive visualizations (Rover)
    - Architecture documentation

  🚀 Kubernetes Applications:
    - Architecture diagrams (Diagrams-as-Code)
    - Resource dependency maps
    - Namespace overviews

  📚 Unified Documentation:
    - Combined architecture overview
    - Cross-layer dependency mapping
    - Environment comparison matrix

TOOLS USED:
  • terraform graph + GraphViz
  • Rover (interactive Terraform visualization)
  • Python diagrams-as-code library
  • kubectl for live cluster data
  • Custom documentation generators

EOF
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
        --terraform-only)
            TERRAFORM_ONLY=true
            KUBERNETES_ONLY=false
            FULL_SUITE=false
            shift
            ;;
        --kubernetes-only)
            KUBERNETES_ONLY=true
            TERRAFORM_ONLY=false
            FULL_SUITE=false
            shift
            ;;
        --cleanup)
            CLEANUP_AFTER=true
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for infrastructure visualization..."

    local missing_tools=()
    local optional_tools=()

    # Required tools
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    fi

    if ! command -v dot &> /dev/null; then
        missing_tools+=("graphviz (for dot command)")
    fi

    # Optional tools
    if ! command -v docker &> /dev/null; then
        optional_tools+=("docker (for Rover)")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  📦 terraform: https://terraform.io/downloads"
        echo "  ⚓ kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  🐍 python3: https://python.org/downloads/"
        echo "  📊 graphviz: brew install graphviz (macOS) or apt-get install graphviz (Ubuntu)"
        echo "  🐳 docker: https://docker.com/get-started (optional)"
        exit 1
    fi

    if [ ${#optional_tools[@]} -ne 0 ]; then
        log_warn "Optional tools missing: ${optional_tools[*]}"
        log_warn "Some visualizations may not be available"
    fi

    log_success "Prerequisites check complete"
}

# Create output directory structure
setup_output_directory() {
    log_info "Setting up output directory structure..."
    
    mkdir -p "$OUTPUT_DIR"/{terraform,kubernetes,unified}
    
    # Create index.html for easy navigation
    cat > "$OUTPUT_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ML Platform Infrastructure Diagrams</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .section { margin: 20px 0; padding: 20px; border-left: 4px solid #3498db; background: #f8f9fa; }
        .diagram-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .diagram-card { border: 1px solid #ddd; border-radius: 8px; padding: 15px; background: white; }
        .diagram-card h3 { margin-top: 0; color: #2c3e50; }
        .diagram-card a { color: #3498db; text-decoration: none; }
        .diagram-card a:hover { text-decoration: underline; }
        .metadata { background: #ecf0f1; padding: 10px; border-radius: 4px; font-size: 0.9em; }
        .tag { background: #3498db; color: white; padding: 2px 8px; border-radius: 12px; font-size: 0.8em; margin-right: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏗️ ML Platform Infrastructure Diagrams</h1>
        
        <div class="metadata">
            <strong>Environment:</strong> ${ENVIRONMENT} <br>
            <strong>Generated:</strong> $(date) <br>
            <strong>Format:</strong> ${FORMAT}
        </div>

        <div class="section">
            <h2>📊 Terraform Infrastructure</h2>
            <p>Infrastructure as Code visualizations showing resource dependencies and cloud architecture.</p>
            <div class="diagram-grid" id="terraform-diagrams">
                <!-- Terraform diagrams will be populated by script -->
            </div>
        </div>

        <div class="section">
            <h2>🚀 Kubernetes Applications</h2>
            <p>Application layer visualizations showing pod, service, and workload relationships.</p>
            <div class="diagram-grid" id="kubernetes-diagrams">
                <!-- Kubernetes diagrams will be populated by script -->
            </div>
        </div>

        <div class="section">
            <h2>🔗 Unified Architecture</h2>
            <p>Cross-platform views combining infrastructure and application layers.</p>
            <div class="diagram-grid" id="unified-diagrams">
                <!-- Unified diagrams will be populated by script -->
            </div>
        </div>

        <div class="section">
            <h2>📚 Documentation</h2>
            <p>Generated documentation and metadata files.</p>
            <div class="diagram-grid" id="documentation">
                <!-- Documentation files will be populated by script -->
            </div>
        </div>
    </div>
</body>
</html>
EOF

    log_success "Output directory structure created: $OUTPUT_DIR"
}

# Generate Terraform visualizations
generate_terraform_visualizations() {
    log_step "Generating Terraform infrastructure visualizations..."
    
    local terraform_script="${SCRIPT_DIR}/terraform-visualize.sh"
    local terraform_args="-e $ENVIRONMENT -f $FORMAT --output-dir $OUTPUT_DIR/terraform"
    
    if [[ "$OPEN_BROWSER" == false ]]; then
        terraform_args="$terraform_args"
    else
        terraform_args="$terraform_args -o"
    fi
    
    if [[ -x "$terraform_script" ]]; then
        log_info "Running Terraform visualization script..."
        "$terraform_script" $terraform_args
    else
        log_error "Terraform visualization script not found: $terraform_script"
        return 1
    fi
    
    log_success "Terraform visualizations generated"
}

# Generate Kubernetes visualizations
generate_kubernetes_visualizations() {
    log_step "Generating Kubernetes application visualizations..."
    
    local kubernetes_script="${SCRIPT_DIR}/kubernetes-visualize.sh"
    local kubernetes_args="-e $ENVIRONMENT -f $FORMAT --output-dir $OUTPUT_DIR/kubernetes"
    
    if [[ "$OPEN_BROWSER" == false ]]; then
        kubernetes_args="$kubernetes_args"
    else
        kubernetes_args="$kubernetes_args -o"
    fi
    
    if [[ -x "$kubernetes_script" ]]; then
        log_info "Running Kubernetes visualization script..."
        "$kubernetes_script" $kubernetes_args
    else
        log_error "Kubernetes visualization script not found: $kubernetes_script"
        return 1
    fi
    
    log_success "Kubernetes visualizations generated"
}

# Generate unified cross-platform documentation
generate_unified_documentation() {
    log_step "Generating unified cross-platform documentation..."
    
    local unified_doc="${OUTPUT_DIR}/unified/architecture-overview.md"
    
    cat > "$unified_doc" << EOF
# ML Platform Architecture Overview

**Environment:** ${ENVIRONMENT}  
**Generated:** $(date)  
**Visualization Format:** ${FORMAT}

## 🏗️ Two-Layer Architecture

The ML Platform follows a comprehensive two-layer architecture pattern:

### Layer 1: Infrastructure (Terraform)
- **Purpose**: Foundational cloud resources and Kubernetes clusters
- **Tools**: Terraform with custom Kind provider for local development
- **Scope**: Compute, storage, networking, security, monitoring foundations

### Layer 2: Applications (Kustomize + ArgoCD)
- **Purpose**: Application deployments and GitOps workflows
- **Tools**: Kustomize for configuration management, ArgoCD for continuous deployment
- **Scope**: ML services, data processing, web interfaces, monitoring dashboards

## 📊 Infrastructure Layer Details

### Cloud Resources (${ENVIRONMENT})
EOF

    # Add environment-specific details
    case $ENVIRONMENT in
        local)
            cat >> "$unified_doc" << EOF
- **Cluster**: Kind (Kubernetes in Docker)
- **Database**: PostgreSQL container
- **Cache**: Redis container
- **Storage**: MinIO container (S3-compatible)
- **Registry**: Local Docker registry
- **Ingress**: NGINX Ingress Controller
EOF
            ;;
        dev|staging|prod)
            cat >> "$unified_doc" << EOF
- **Cluster**: AWS EKS
- **Database**: RDS PostgreSQL
- **Cache**: ElastiCache Redis
- **Storage**: S3 buckets
- **Registry**: ECR
- **Ingress**: Application Load Balancer
EOF
            ;;
    esac

    cat >> "$unified_doc" << EOF

### Security Features
- 🔒 **Network Policies**: Pod-to-pod communication control
- 🔐 **RBAC**: Role-based access control
- 🛡️ **Pod Security**: Non-root containers, read-only filesystems
- 🔑 **Secret Management**: Kubernetes secrets with external integration
- 📋 **Compliance**: Security scanning and policy enforcement

## 🚀 Application Layer Details

### Core Services
- **Backend API**: FastAPI-based ML platform API
- **Frontend**: React web dashboard
- **ML Service**: Training and inference workloads
- **Data Processing**: ETL and feature engineering pipelines

### GitOps Workflow
1. **Code Changes**: Developers push to Git repositories
2. **ArgoCD Sync**: Automatically detects and applies changes
3. **Deployment**: Rolling updates with health checks
4. **Monitoring**: Observability throughout the process

## 🔗 Cross-Layer Dependencies

### Data Flow
\`\`\`
Users → Ingress → Frontend/Backend → ML Services → Data Storage
                      ↓
                 Monitoring ← GitOps Management
\`\`\`

### Service Mesh
- **East-West Traffic**: Pod-to-pod communication within cluster
- **North-South Traffic**: External user access via ingress
- **Observability**: Distributed tracing with Jaeger

## 📈 Monitoring & Observability

### Metrics Collection
- **Infrastructure**: Node and cluster metrics
- **Applications**: Custom business metrics
- **Performance**: Response times and throughput
- **Health**: Service availability and error rates

### Visualization Tools
- **Grafana**: Interactive dashboards
- **Prometheus**: Metrics storage and alerting
- **Jaeger**: Distributed request tracing
- **ArgoCD UI**: Deployment status and history

## 🔄 Environment Progression

| Aspect | Local | Dev | Staging | Prod |
|--------|-------|-----|---------|------|
| **Infrastructure** | Kind | EKS (2 AZ) | EKS (3 AZ) | EKS (3 AZ) |
| **Data** | Containers | RDS Single | RDS Multi-AZ | RDS Multi-AZ |
| **Scaling** | Manual | Basic HPA | Advanced HPA | Full Auto-scaling |
| **Security** | Basic | Enhanced | Production | Enterprise |
| **Monitoring** | Local | CloudWatch | Full Stack | 24/7 Alerting |

## 📁 Generated Diagrams

### Terraform Infrastructure
- \`terraform/terraform-${ENVIRONMENT}-graph.${FORMAT}\` - Resource dependency graph
- \`terraform/terraform-${ENVIRONMENT}-rover.html\` - Interactive exploration
- \`terraform/terraform-${ENVIRONMENT}-docs.md\` - Documentation

### Kubernetes Applications
- \`kubernetes/kubernetes-${ENVIRONMENT}-architecture.${FORMAT}\` - Application architecture
- \`kubernetes/kubernetes-${ENVIRONMENT}-detailed.${FORMAT}\` - Resource details
- \`kubernetes/kubernetes-${ENVIRONMENT}-namespaces.md\` - Namespace overview

## 🚀 Next Steps

1. **Review Diagrams**: Examine generated visualizations for your environment
2. **Validate Architecture**: Ensure the design meets your requirements
3. **Share with Team**: Use diagrams for architectural discussions
4. **Keep Updated**: Regenerate diagrams when infrastructure changes
5. **Automate**: Consider adding visualization to CI/CD pipelines

## 🔧 Maintenance

### Regular Updates
- Regenerate diagrams monthly or after major changes
- Update documentation to reflect architectural evolution
- Share visualizations in architectural review meetings

### Troubleshooting
- Use diagrams to understand service dependencies during incidents
- Reference architecture for capacity planning
- Validate security posture against documented design

---

**Generated by ML Platform Infrastructure Visualization Suite**  
**For questions or updates, see the infrastructure documentation.**
EOF

    log_success "Unified documentation generated: $unified_doc"
    echo "$unified_doc"
}

# Update index.html with generated files
update_index_html() {
    log_info "Updating navigation index..."
    
    local index_file="$OUTPUT_DIR/index.html"
    local temp_file=$(mktemp)
    
    # Function to add diagram entries to HTML
    add_diagram_entries() {
        local section=$1
        local pattern=$2
        local description=$3
        
        echo "            <script>" >> "$temp_file"
        echo "            // Add $section diagrams" >> "$temp_file"
        echo "            var ${section}Container = document.getElementById('${section}-diagrams');" >> "$temp_file"
        
        for file in "$OUTPUT_DIR"/$pattern; do
            if [[ -f "$file" ]]; then
                local basename=$(basename "$file")
                local relative_path="${pattern%/*}/$basename"
                local file_size=$(du -h "$file" | cut -f1)
                
                echo "            ${section}Container.innerHTML += \`" >> "$temp_file"
                echo "                <div class=\"diagram-card\">" >> "$temp_file"
                echo "                    <h3>📊 $basename</h3>" >> "$temp_file"
                echo "                    <p>$description</p>" >> "$temp_file"
                echo "                    <p><strong>Size:</strong> $file_size</p>" >> "$temp_file"
                echo "                    <a href=\"$relative_path\" target=\"_blank\">Open Diagram</a>" >> "$temp_file"
                echo "                </div>" >> "$temp_file"
                echo "            \`;" >> "$temp_file"
            fi
        done
        
        echo "            </script>" >> "$temp_file"
    }
    
    # Copy the HTML template and add dynamic content
    cp "$index_file" "$temp_file"
    
    # Add diagram entries for each section
    sed -i.bak '/<!-- Terraform diagrams will be populated by script -->/r /dev/stdin' "$temp_file" <<< "$(add_diagram_entries terraform "terraform/*" "Infrastructure resource dependencies and cloud architecture")"
    
    sed -i.bak '/<!-- Kubernetes diagrams will be populated by script -->/r /dev/stdin' "$temp_file" <<< "$(add_diagram_entries kubernetes "kubernetes/*" "Application layer and service relationships")"
    
    sed -i.bak '/<!-- Unified diagrams will be populated by script -->/r /dev/stdin' "$temp_file" <<< "$(add_diagram_entries unified "unified/*" "Cross-platform architecture overview")"
    
    sed -i.bak '/<!-- Documentation files will be populated by script -->/r /dev/stdin' "$temp_file" <<< "$(add_diagram_entries documentation "*/*.md" "Generated documentation and metadata")"
    
    # Replace the original file
    mv "$temp_file" "$index_file"
    rm -f "${temp_file}.bak"
    
    log_success "Navigation index updated: $index_file"
}

# Cleanup temporary files
cleanup_temp_files() {
    if [[ "$CLEANUP_AFTER" == true ]]; then
        log_info "Cleaning up temporary files..."
        
        # Remove any .tmp files
        find "$OUTPUT_DIR" -name "*.tmp" -delete 2>/dev/null || true
        
        # Remove backup files
        find "$OUTPUT_DIR" -name "*.bak" -delete 2>/dev/null || true
        
        log_success "Temporary files cleaned up"
    fi
}

# Open visualization suite in browser
open_visualization_suite() {
    if [[ "$OPEN_BROWSER" == true ]]; then
        log_info "Opening visualization suite in browser..."
        
        local index_file="$OUTPUT_DIR/index.html"
        
        case "$OSTYPE" in
            darwin*)  # macOS
                open "$index_file"
                ;;
            linux*)   # Linux
                xdg-open "$index_file" 2>/dev/null || true
                ;;
            msys*)    # Windows (Git Bash)
                start "$index_file"
                ;;
            *)
                log_warn "Cannot auto-open browser on this platform"
                log_info "Manually open: $index_file"
                ;;
        esac
    fi
}

# Display summary of generated files
display_summary() {
    echo ""
    log_success "🎉 Infrastructure visualization suite complete!"
    echo ""
    echo "📁 Output directory: $OUTPUT_DIR"
    echo ""
    echo "Generated visualizations:"
    
    local file_count=0
    
    # Count and display Terraform files
    if [[ "$TERRAFORM_ONLY" == true ]] || [[ "$FULL_SUITE" == true ]]; then
        local tf_files=($(find "$OUTPUT_DIR/terraform" -type f 2>/dev/null || true))
        if [ ${#tf_files[@]} -gt 0 ]; then
            echo "  📊 Terraform Infrastructure: ${#tf_files[@]} files"
            file_count=$((file_count + ${#tf_files[@]}))
        fi
    fi
    
    # Count and display Kubernetes files
    if [[ "$KUBERNETES_ONLY" == true ]] || [[ "$FULL_SUITE" == true ]]; then
        local k8s_files=($(find "$OUTPUT_DIR/kubernetes" -type f 2>/dev/null || true))
        if [ ${#k8s_files[@]} -gt 0 ]; then
            echo "  🚀 Kubernetes Applications: ${#k8s_files[@]} files"
            file_count=$((file_count + ${#k8s_files[@]}))
        fi
    fi
    
    # Count and display unified files
    if [[ "$FULL_SUITE" == true ]]; then
        local unified_files=($(find "$OUTPUT_DIR/unified" -type f 2>/dev/null || true))
        if [ ${#unified_files[@]} -gt 0 ]; then
            echo "  🔗 Unified Documentation: ${#unified_files[@]} files"
            file_count=$((file_count + ${#unified_files[@]}))
        fi
    fi
    
    echo ""
    echo "Total files generated: $file_count"
    echo ""
    echo "🌐 Open visualization suite: $OUTPUT_DIR/index.html"
    echo ""
    echo "🔧 Next steps:"
    echo "  1. Review the generated diagrams and documentation"
    echo "  2. Share with your team for architecture discussions"
    echo "  3. Update diagrams when infrastructure changes"
    echo "  4. Consider automating visualization in CI/CD pipelines"
}

# Main execution
main() {
    echo ""
    log_step "🏗️ ML Platform Infrastructure Visualization Suite"
    echo ""
    log_info "Environment: $ENVIRONMENT | Format: $FORMAT | Output: $OUTPUT_DIR"
    echo ""
    
    check_prerequisites
    setup_output_directory
    
    # Generate visualizations based on selection
    if [[ "$TERRAFORM_ONLY" == true ]]; then
        generate_terraform_visualizations
    elif [[ "$KUBERNETES_ONLY" == true ]]; then
        generate_kubernetes_visualizations
    else
        # Full suite
        generate_terraform_visualizations
        generate_kubernetes_visualizations
        generate_unified_documentation
    fi
    
    update_index_html
    cleanup_temp_files
    
    display_summary
    open_visualization_suite
}

# Execute main function
main "$@"