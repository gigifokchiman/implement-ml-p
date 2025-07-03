#!/bin/bash
# ArgoCD GitOps Visualization Script
# Generates visual diagrams of ArgoCD applications and their dependencies

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
OUTPUT_DIR="${SCRIPT_DIR}/../../docs/diagrams/gitops"
KUBERNETES_DIR="${SCRIPT_DIR}/../../kubernetes"

# Default values
ENVIRONMENT="local"
NAMESPACE="argocd"
FORMAT="png"
OPEN_BROWSER=false
USE_LIVE_CLUSTER=true

# Parse command line arguments
usage() {
    echo "ArgoCD GitOps Visualization"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment to visualize (local, dev, staging, prod)"
    echo "  -n, --namespace NS       ArgoCD namespace (default: argocd)"
    echo "  -f, --format FORMAT      Output format (png, svg, pdf, html)"
    echo "  -o, --open               Open generated diagrams in browser"
    echo "  --live-cluster           Use live cluster data (default)"
    echo "  --manifests-only         Use manifest files only"
    echo "  --output-dir DIR         Output directory for diagrams"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Visualize local ArgoCD from live cluster"
    echo "  $0 -e prod --manifests-only # Visualize prod ArgoCD from manifests"
    echo "  $0 -f svg -o             # Generate SVG and open in browser"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
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
        --live-cluster)
            USE_LIVE_CLUSTER=true
            shift
            ;;
        --manifests-only)
            USE_LIVE_CLUSTER=false
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
    log_info "Checking prerequisites for ArgoCD visualization..."

    local missing_tools=()

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    fi

    if ! command -v dot &> /dev/null; then
        missing_tools+=("graphviz (dot command)")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi

    # Check if ArgoCD CLI is available
    if command -v argocd &> /dev/null; then
        log_info "ArgoCD CLI found - enhanced features available"
    else
        log_warn "ArgoCD CLI not found - using kubectl for ArgoCD operations"
    fi

    log_success "Prerequisites check complete"
}

# Validate ArgoCD access
validate_argocd_access() {
    if [[ "$USE_LIVE_CLUSTER" == true ]]; then
        log_info "Validating ArgoCD access..."
        
        if ! kubectl cluster-info &> /dev/null; then
            log_error "Cannot access Kubernetes cluster"
            exit 1
        fi
        
        # Check if ArgoCD namespace exists
        if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
            log_error "ArgoCD namespace '$NAMESPACE' not found"
            log_info "Available namespaces:"
            kubectl get namespaces -o name | sed 's/namespace\//  - /'
            exit 1
        fi
        
        # Check if ArgoCD is running
        if ! kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server &> /dev/null; then
            log_warn "ArgoCD server pods not found in namespace '$NAMESPACE'"
        fi
        
        log_success "ArgoCD access validated"
    else
        log_info "Using manifest files for ArgoCD visualization"
    fi
}

# Generate ArgoCD application dependency graph
generate_app_dependency_graph() {
    local output_file="${OUTPUT_DIR}/argocd-${ENVIRONMENT}-app-dependencies.${FORMAT}"
    
    log_info "Generating ArgoCD application dependency graph..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create Python script for ArgoCD visualization
    local python_script="${OUTPUT_DIR}/generate_argocd_graph.py"
    
    cat > "$python_script" << 'EOF'
#!/usr/bin/env python3
"""
ArgoCD Application Dependency Visualization
"""

import json
import subprocess
import sys
from pathlib import Path

try:
    from diagrams import Diagram, Node, Cluster, Edge
    from diagrams.k8s.clusterconfig import Namespace
    from diagrams.onprem.gitops import ArgoCD
    from diagrams.programming.flowchart import StartEnd, Decision, Action
    from diagrams.onprem.vcs import Git
    from diagrams.k8s.compute import Deployment
    from diagrams.k8s.network import Service
except ImportError as e:
    print(f"Error importing diagrams library: {e}")
    print("Install with: pip3 install diagrams")
    sys.exit(1)

def get_argocd_applications(namespace, use_live_cluster):
    """Get ArgoCD applications from cluster or manifests"""
    applications = []
    
    if use_live_cluster:
        try:
            # Get applications using kubectl
            result = subprocess.run([
                'kubectl', 'get', 'applications', '-n', namespace, '-o', 'json'
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                applications = data.get('items', [])
            else:
                print(f"Failed to get applications: {result.stderr}")
        except Exception as e:
            print(f"Error getting applications: {e}")
    else:
        # Parse manifest files for ArgoCD applications
        print("Parsing ArgoCD applications from manifests...")
        # This would parse YAML files in the gitops directory
        
    return applications

def analyze_app_dependencies(applications):
    """Analyze dependencies between ArgoCD applications"""
    dependencies = {}
    
    for app in applications:
        app_name = app['metadata']['name']
        spec = app.get('spec', {})
        
        # Extract source information
        source = spec.get('source', {})
        repo_url = source.get('repoURL', '')
        path = source.get('path', '')
        target_revision = source.get('targetRevision', 'HEAD')
        
        # Extract destination
        destination = spec.get('destination', {})
        dest_namespace = destination.get('namespace', 'default')
        dest_server = destination.get('server', '')
        
        dependencies[app_name] = {
            'repo': repo_url,
            'path': path,
            'revision': target_revision,
            'namespace': dest_namespace,
            'server': dest_server,
            'sync_policy': spec.get('syncPolicy', {}),
            'status': app.get('status', {})
        }
    
    return dependencies

def generate_gitops_flow_diagram(output_dir, environment, format_type, dependencies):
    """Generate GitOps workflow diagram"""
    output_file = f"argocd-{environment}-gitops-flow"
    
    with Diagram(
        f"GitOps Workflow - {environment.title()}",
        filename=f"{output_dir}/{output_file}",
        format=format_type,
        show=False,
        direction="LR"
    ):
        # Git repository
        git_repo = Git("Git Repository\n(Source of Truth)")
        
        # ArgoCD components
        with Cluster("ArgoCD"):
            argocd_server = ArgoCD("ArgoCD Server")
            app_controller = Node("Application Controller")
        
        # Kubernetes cluster
        with Cluster("Kubernetes Cluster"):
            namespaces = {}
            for app_name, info in dependencies.items():
                ns_name = info['namespace']
                if ns_name not in namespaces:
                    namespaces[ns_name] = Cluster(f"Namespace: {ns_name}")
                
                with namespaces[ns_name]:
                    Deployment(f"App: {app_name}")
        
        # Workflow connections
        git_repo >> argocd_server
        argocd_server >> app_controller
        
        for ns_cluster in namespaces.values():
            app_controller >> ns_cluster

def generate_app_status_diagram(output_dir, environment, format_type, dependencies):
    """Generate application status overview"""
    output_file = f"argocd-{environment}-app-status"
    
    with Diagram(
        f"ArgoCD Applications Status - {environment.title()}",
        filename=f"{output_dir}/{output_file}",
        format=format_type,
        show=False,
        direction="TB"
    ):
        # Group applications by sync status
        synced_apps = []
        out_of_sync_apps = []
        unknown_apps = []
        
        for app_name, info in dependencies.items():
            sync_status = info['status'].get('sync', {}).get('status', 'Unknown')
            health_status = info['status'].get('health', {}).get('status', 'Unknown')
            
            if sync_status == 'Synced':
                synced_apps.append((app_name, health_status))
            elif sync_status == 'OutOfSync':
                out_of_sync_apps.append((app_name, health_status))
            else:
                unknown_apps.append((app_name, health_status))
        
        # Create clusters for each status
        if synced_apps:
            with Cluster("✅ Synced Applications"):
                for app_name, health in synced_apps:
                    color = "green" if health == "Healthy" else "orange"
                    ArgoCD(f"{app_name}\n({health})")
        
        if out_of_sync_apps:
            with Cluster("⚠️ Out of Sync Applications"):
                for app_name, health in out_of_sync_apps:
                    ArgoCD(f"{app_name}\n({health})")
        
        if unknown_apps:
            with Cluster("❓ Unknown Status Applications"):
                for app_name, health in unknown_apps:
                    ArgoCD(f"{app_name}\n({health})")

def main():
    if len(sys.argv) < 5:
        print("Usage: python3 generate_argocd_graph.py <namespace> <environment> <output_dir> <format> <use_live_cluster>")
        sys.exit(1)
    
    namespace = sys.argv[1]
    environment = sys.argv[2]
    output_dir = sys.argv[3]
    format_type = sys.argv[4]
    use_live_cluster = sys.argv[5].lower() == 'true'
    
    # Ensure output directory exists
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    print(f"Getting ArgoCD applications from namespace {namespace}...")
    applications = get_argocd_applications(namespace, use_live_cluster)
    print(f"Found {len(applications)} ArgoCD applications")
    
    if not applications:
        print("No ArgoCD applications found. Creating example diagram...")
        dependencies = {
            'ml-platform-local': {
                'repo': 'https://github.com/example/ml-platform',
                'path': 'kubernetes/overlays/local',
                'revision': 'HEAD',
                'namespace': 'ml-platform',
                'status': {'sync': {'status': 'Synced'}, 'health': {'status': 'Healthy'}}
            },
            'monitoring': {
                'repo': 'https://github.com/example/ml-platform',
                'path': 'kubernetes/base/monitoring',
                'revision': 'HEAD',
                'namespace': 'monitoring',
                'status': {'sync': {'status': 'Synced'}, 'health': {'status': 'Healthy'}}
            }
        }
    else:
        dependencies = analyze_app_dependencies(applications)
    
    # Generate GitOps workflow diagram
    print("Generating GitOps workflow diagram...")
    generate_gitops_flow_diagram(output_dir, environment, format_type, dependencies)
    
    # Generate application status diagram
    print("Generating application status diagram...")
    generate_app_status_diagram(output_dir, environment, format_type, dependencies)
    
    print(f"ArgoCD diagrams generated in {output_dir}/")

if __name__ == "__main__":
    main()
EOF

    # Make Python script executable
    chmod +x "$python_script"
    
    # Run the Python script
    log_info "Running ArgoCD visualization generation..."
    python3 "$python_script" "$NAMESPACE" "$ENVIRONMENT" "$OUTPUT_DIR" "$FORMAT" "$USE_LIVE_CLUSTER"
    
    # Clean up the generated Python script
    rm "$python_script"
    
    # Return generated files
    local generated_files=()
    for file in "${OUTPUT_DIR}/argocd-${ENVIRONMENT}-"*.{png,svg,pdf}; do
        if [[ -f "$file" ]]; then
            generated_files+=("$file")
        fi
    done
    
    if [ ${#generated_files[@]} -gt 0 ]; then
        log_success "ArgoCD visualizations generated"
        printf '%s\n' "${generated_files[@]}"
    else
        log_error "Failed to generate ArgoCD visualizations"
        return 1
    fi
}

# Generate ArgoCD configuration overview
generate_argocd_overview() {
    local output_file="${OUTPUT_DIR}/argocd-${ENVIRONMENT}-overview.md"
    
    log_info "Generating ArgoCD configuration overview..."
    
    cat > "$output_file" << EOF
# ArgoCD GitOps Overview - ${ENVIRONMENT}

**Generated:** $(date)
**Environment:** ${ENVIRONMENT}
**Namespace:** ${NAMESPACE}

## 🚀 GitOps Architecture

### ArgoCD Components
EOF

    if [[ "$USE_LIVE_CLUSTER" == true ]]; then
        echo "### Live Cluster Status" >> "$output_file"
        echo '```' >> "$output_file"
        kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null | head -20 >> "$output_file" || echo "ArgoCD pods not found" >> "$output_file"
        echo '```' >> "$output_file"
        
        echo "" >> "$output_file"
        echo "### ArgoCD Applications" >> "$output_file"
        echo '```' >> "$output_file"
        kubectl get applications -n "$NAMESPACE" 2>/dev/null | head -20 >> "$output_file" || echo "No applications found" >> "$output_file"
        echo '```' >> "$output_file"
        
        echo "" >> "$output_file"
        echo "### Application Projects" >> "$output_file"
        echo '```' >> "$output_file"
        kubectl get appprojects -n "$NAMESPACE" 2>/dev/null | head -10 >> "$output_file" || echo "No projects found" >> "$output_file"
        echo '```' >> "$output_file"
    else
        echo "### Configuration Files" >> "$output_file"
        
        # List ArgoCD configuration files
        local gitops_dir="${KUBERNETES_DIR}/base/gitops"
        if [[ -d "$gitops_dir" ]]; then
            echo '```' >> "$output_file"
            find "$gitops_dir" -name "*.yaml" | head -20 >> "$output_file"
            echo '```' >> "$output_file"
        fi
    fi

    cat >> "$output_file" << EOF

## 🔄 GitOps Workflow

### 1. Source Repository
- **Repository**: Git repository containing Kubernetes manifests
- **Structure**: Organized with base configurations and environment overlays
- **Kustomize**: Used for configuration management

### 2. ArgoCD Synchronization
- **Polling**: Regular checks for repository changes
- **Webhooks**: Immediate notification of Git commits
- **Sync Policy**: Automated or manual synchronization

### 3. Deployment Process
- **Validation**: Manifest validation before apply
- **Rollout**: Progressive deployment with health checks
- **Monitoring**: Continuous health and sync status monitoring

## 📊 Application Dependencies

### ML Platform Components
- **ml-platform-${ENVIRONMENT}**: Main application stack
- **monitoring**: Observability components
- **storage**: Data storage services
- **security**: RBAC and network policies

### Sync Strategies
- **Auto-sync**: Automatic deployment on Git changes
- **Manual sync**: Operator-controlled deployments
- **Sync windows**: Scheduled deployment windows

## 🔒 Security Configuration

### RBAC
- Service accounts with minimal privileges
- Role-based access control for ArgoCD users
- Project-based application isolation

### Git Access
- SSH keys or personal access tokens
- Repository access permissions
- Branch protection rules

## 📈 Monitoring & Observability

### ArgoCD Metrics
- Application sync status
- Deployment frequency
- Error rates and failures

### Integration with Monitoring Stack
- Prometheus metrics collection
- Grafana dashboards
- Alerting on sync failures

## 🔧 Troubleshooting

### Common Issues
1. **Sync Failures**: Check application logs and events
2. **Out of Sync**: Verify Git repository connectivity
3. **Health Degraded**: Investigate target resource status

### Useful Commands
\`\`\`bash
# Check application status
kubectl get applications -n ${NAMESPACE}

# View application details
kubectl describe application <app-name> -n ${NAMESPACE}

# Check ArgoCD server logs
kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=argocd-server

# Access ArgoCD UI
kubectl port-forward -n ${NAMESPACE} svc/argocd-server 8080:443
\`\`\`

## 📁 Generated Diagrams

- \`argocd-${ENVIRONMENT}-gitops-flow.${FORMAT}\` - GitOps workflow visualization
- \`argocd-${ENVIRONMENT}-app-status.${FORMAT}\` - Application status overview
- \`argocd-${ENVIRONMENT}-overview.md\` - This configuration summary

---

**Note:** This overview is auto-generated. For the latest ArgoCD configuration, refer to the Kubernetes manifests in the gitops directory.
EOF

    log_success "ArgoCD overview generated: $output_file"
    echo "$output_file"
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
    log_info "Starting ArgoCD GitOps visualization for environment: $ENVIRONMENT"
    
    check_prerequisites
    validate_argocd_access
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local generated_files=()
    
    # Install Python diagrams library if needed
    if ! python3 -c "import diagrams" &> /dev/null; then
        log_info "Installing Python diagrams library..."
        pip3 install diagrams graphviz --user || {
            log_error "Failed to install diagrams library"
            exit 1
        }
    fi
    
    # Generate ArgoCD application dependency graphs
    if readarray -t diagram_files < <(generate_app_dependency_graph); then
        generated_files+=("${diagram_files[@]}")
    fi
    
    # Generate ArgoCD overview documentation
    if overview_file=$(generate_argocd_overview); then
        generated_files+=("$overview_file")
    fi
    
    # Display results
    echo ""
    log_success "ArgoCD GitOps visualization complete!"
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
    echo "  1. Review ArgoCD application dependencies and status"
    echo "  2. Check GitOps workflow visualization for process understanding"
    echo "  3. Use overview documentation for operational planning"
    echo "  4. Update visualizations when ArgoCD configuration changes"
}

# Execute main function
main "$@"