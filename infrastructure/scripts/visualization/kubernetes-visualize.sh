#!/bin/bash
# Kubernetes Infrastructure Visualization Script
# Generates visual diagrams from Kubernetes configurations using multiple tools

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
KUBERNETES_DIR="${SCRIPT_DIR}/../../kubernetes"

# Default values
ENVIRONMENT="local"
NAMESPACE="ml-platform"
FORMAT="png"
OPEN_BROWSER=false
USE_LIVE_CLUSTER=false
USE_DIAGRAMS_AS_CODE=true
USE_KUBECTL_GRAPH=false

# Parse command line arguments
usage() {
    echo "Kubernetes Infrastructure Visualization"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment to visualize (local, dev, staging, prod)"
    echo "  -n, --namespace NS       Kubernetes namespace to focus on (default: ml-platform)"
    echo "  -f, --format FORMAT      Output format (png, svg, pdf, py)"
    echo "  -o, --open               Open generated diagrams in browser"
    echo "  --live-cluster           Use live cluster data instead of manifests"
    echo "  --use-diagrams-as-code   Use Python diagrams-as-code library (default)"
    echo "  --use-kubectl-graph      Use kubectl-graph plugin"
    echo "  --output-dir DIR         Output directory for diagrams"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Visualize local Kubernetes manifests"
    echo "  $0 -e prod --live-cluster # Visualize live production cluster"
    echo "  $0 -n argocd -f svg     # Visualize ArgoCD namespace as SVG"
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
        --use-diagrams-as-code)
            USE_DIAGRAMS_AS_CODE=true
            USE_KUBECTL_GRAPH=false
            shift
            ;;
        --use-kubectl-graph)
            USE_KUBECTL_GRAPH=true
            USE_DIAGRAMS_AS_CODE=false
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
    log_info "Checking prerequisites for Kubernetes visualization..."

    local missing_tools=()

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if [[ "$USE_DIAGRAMS_AS_CODE" == true ]] && ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    fi

    if [[ "$USE_KUBECTL_GRAPH" == true ]] && ! kubectl plugin list | grep -q "kubectl-graph"; then
        log_warn "kubectl-graph plugin not found, will install it"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install instructions:"
        echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  - python3: https://python.org/downloads/"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Install Python dependencies
setup_python_environment() {
    if [[ "$USE_DIAGRAMS_AS_CODE" == true ]]; then
        log_info "Setting up Python environment for diagrams-as-code..."
        
        # Check if diagrams library is installed
        if ! python3 -c "import diagrams" &> /dev/null; then
            log_info "Installing diagrams library..."
            pip3 install diagrams graphviz --user || {
                log_error "Failed to install diagrams library"
                log_info "Try: pip3 install --user diagrams graphviz"
                exit 1
            }
        fi
        
        log_success "Python environment ready"
    fi
}

# Install kubectl-graph plugin
setup_kubectl_graph() {
    if [[ "$USE_KUBECTL_GRAPH" == true ]]; then
        log_info "Setting up kubectl-graph plugin..."
        
        if ! kubectl plugin list | grep -q "kubectl-graph"; then
            log_info "Installing kubectl-graph plugin..."
            
            # Download and install kubectl-graph
            local plugin_url="https://github.com/steveteuber/kubectl-graph/releases/latest/download/kubectl-graph"
            local install_path="${HOME}/.local/bin/kubectl-graph"
            
            mkdir -p "${HOME}/.local/bin"
            curl -L "$plugin_url" -o "$install_path"
            chmod +x "$install_path"
            
            # Add to PATH if not already there
            if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
                log_warn "Add ${HOME}/.local/bin to your PATH to use kubectl-graph"
            fi
        fi
        
        log_success "kubectl-graph plugin ready"
    fi
}

# Validate Kubernetes access
validate_kubernetes_access() {
    if [[ "$USE_LIVE_CLUSTER" == true ]]; then
        log_info "Validating Kubernetes cluster access..."
        
        if ! kubectl cluster-info &> /dev/null; then
            log_error "Cannot access Kubernetes cluster"
            log_info "Make sure kubectl is configured and cluster is running"
            exit 1
        fi
        
        # Check if namespace exists
        if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
            log_warn "Namespace '$NAMESPACE' not found in cluster"
            log_info "Available namespaces:"
            kubectl get namespaces -o name | sed 's/namespace\//  - /'
        fi
        
        log_success "Kubernetes cluster access validated"
    else
        log_info "Using manifest files for visualization (not live cluster)"
    fi
}

# Generate diagrams using Python diagrams-as-code
generate_diagrams_as_code() {
    local output_file="${OUTPUT_DIR}/kubernetes-${ENVIRONMENT}-architecture.${FORMAT}"
    
    log_info "Generating architecture diagram using diagrams-as-code..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create Python script for diagram generation
    local python_script="${OUTPUT_DIR}/generate_k8s_diagram.py"
    
    cat > "$python_script" << 'EOF'
#!/usr/bin/env python3
"""
Kubernetes Infrastructure Visualization using Diagrams-as-Code
Generates architecture diagrams from Kubernetes manifests or live cluster data
"""

import os
import sys
import yaml
import glob
from pathlib import Path

# Import diagrams library
try:
    from diagrams import Diagram, Node, Cluster, Edge
    from diagrams.k8s.clusterconfig import Namespace
    from diagrams.k8s.compute import Deployment, Pod, ReplicaSet, Job, CronJob
    from diagrams.k8s.network import Service, Ingress
    from diagrams.k8s.storage import PV, PVC, StorageClass
    from diagrams.k8s.rbac import ServiceAccount, Role, RoleBinding
    from diagrams.onprem.database import PostgreSQL
    from diagrams.onprem.inmemory import Redis
    from diagrams.onprem.storage import Minio
    from diagrams.onprem.monitoring import Prometheus, Grafana
    from diagrams.onprem.gitops import ArgoCD
    from diagrams.programming.framework import FastAPI, React
except ImportError as e:
    print(f"Error importing diagrams library: {e}")
    print("Install with: pip3 install diagrams")
    sys.exit(1)

def load_kubernetes_manifests(kubernetes_dir, environment):
    """Load Kubernetes manifests from directory structure"""
    manifests = []
    
    # Base manifests
    base_dir = Path(kubernetes_dir) / "base"
    if base_dir.exists():
        for yaml_file in base_dir.rglob("*.yaml"):
            try:
                with open(yaml_file, 'r') as f:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and 'kind' in doc:
                            manifests.append(doc)
            except Exception as e:
                print(f"Warning: Could not parse {yaml_file}: {e}")
    
    # Environment-specific overlays
    overlay_dir = Path(kubernetes_dir) / "overlays" / environment
    if overlay_dir.exists():
        for yaml_file in overlay_dir.rglob("*.yaml"):
            try:
                with open(yaml_file, 'r') as f:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and 'kind' in doc:
                            manifests.append(doc)
            except Exception as e:
                print(f"Warning: Could not parse {yaml_file}: {e}")
    
    return manifests

def categorize_resources(manifests):
    """Categorize Kubernetes resources by type"""
    resources = {
        'deployments': [],
        'services': [],
        'ingresses': [],
        'pvcs': [],
        'configmaps': [],
        'secrets': [],
        'jobs': [],
        'cronjobs': [],
        'serviceaccounts': [],
        'namespaces': [],
        'other': []
    }
    
    for manifest in manifests:
        kind = manifest.get('kind', '').lower()
        if kind == 'deployment':
            resources['deployments'].append(manifest)
        elif kind == 'service':
            resources['services'].append(manifest)
        elif kind == 'ingress':
            resources['ingresses'].append(manifest)
        elif kind == 'persistentvolumeclaim':
            resources['pvcs'].append(manifest)
        elif kind == 'configmap':
            resources['configmaps'].append(manifest)
        elif kind == 'secret':
            resources['secrets'].append(manifest)
        elif kind == 'job':
            resources['jobs'].append(manifest)
        elif kind == 'cronjob':
            resources['cronjobs'].append(manifest)
        elif kind == 'serviceaccount':
            resources['serviceaccounts'].append(manifest)
        elif kind == 'namespace':
            resources['namespaces'].append(manifest)
        else:
            resources['other'].append(manifest)
    
    return resources

def generate_ml_platform_diagram(output_dir, environment, format_type):
    """Generate ML Platform architecture diagram"""
    output_file = f"kubernetes-{environment}-architecture"
    
    with Diagram(
        f"ML Platform - {environment.title()} Environment",
        filename=f"{output_dir}/{output_file}",
        format=format_type,
        show=False,
        direction="TB"
    ):
        # External traffic
        users = Node("Users", icon="diagrams.onprem.client.Users")
        
        # Ingress layer
        with Cluster("Ingress"):
            ingress = Ingress("NGINX Ingress")
        
        # Application layer
        with Cluster("ML Platform Applications"):
            frontend = React("Frontend\n(React)")
            backend = FastAPI("Backend API\n(FastAPI)")
            ml_service = Node("ML Service\n(Training/Inference)")
        
        # Data layer
        with Cluster("Data Services"):
            database = PostgreSQL("PostgreSQL\nDatabase")
            cache = Redis("Redis\nCache")
            storage = Minio("MinIO\nObject Storage")
        
        # Monitoring layer
        with Cluster("Monitoring"):
            prometheus = Prometheus("Prometheus\nMetrics")
            grafana = Grafana("Grafana\nDashboards")
        
        # GitOps layer
        with Cluster("GitOps"):
            argocd = ArgoCD("ArgoCD\nDeployment")
        
        # Network connections
        users >> ingress >> [frontend, backend]
        backend >> [database, cache, storage]
        ml_service >> [database, storage]
        [frontend, backend, ml_service] >> prometheus
        prometheus >> grafana
        argocd >> [frontend, backend, ml_service]

def generate_detailed_diagram(output_dir, environment, manifests, format_type):
    """Generate detailed Kubernetes resource diagram"""
    resources = categorize_resources(manifests)
    output_file = f"kubernetes-{environment}-detailed"
    
    with Diagram(
        f"Kubernetes Resources - {environment.title()}",
        filename=f"{output_dir}/{output_file}",
        format=format_type,
        show=False,
        direction="TB"
    ):
        # Group by namespace
        namespaces = {}
        
        # Create namespace clusters
        for ns in resources['namespaces']:
            ns_name = ns['metadata']['name']
            namespaces[ns_name] = Cluster(f"Namespace: {ns_name}")
        
        # Default namespace for resources without explicit namespace
        if not namespaces:
            namespaces['default'] = Cluster("Default Namespace")
        
        # Add deployments
        deployments = {}
        for deployment in resources['deployments']:
            name = deployment['metadata']['name']
            ns = deployment['metadata'].get('namespace', 'default')
            
            with namespaces.get(ns, namespaces['default']):
                deployments[name] = Deployment(f"Deployment\n{name}")
        
        # Add services
        services = {}
        for service in resources['services']:
            name = service['metadata']['name']
            ns = service['metadata'].get('namespace', 'default')
            
            with namespaces.get(ns, namespaces['default']):
                services[name] = Service(f"Service\n{name}")
        
        # Add PVCs
        pvcs = {}
        for pvc in resources['pvcs']:
            name = pvc['metadata']['name']
            ns = pvc['metadata'].get('namespace', 'default')
            
            with namespaces.get(ns, namespaces['default']):
                pvcs[name] = PVC(f"PVC\n{name}")
        
        # Connect services to deployments (simplified)
        for svc_name, svc_node in services.items():
            for dep_name, dep_node in deployments.items():
                if svc_name.startswith(dep_name) or dep_name.startswith(svc_name):
                    svc_node >> dep_node

def main():
    if len(sys.argv) < 4:
        print("Usage: python3 generate_k8s_diagram.py <kubernetes_dir> <environment> <output_dir> [format]")
        sys.exit(1)
    
    kubernetes_dir = sys.argv[1]
    environment = sys.argv[2]
    output_dir = sys.argv[3]
    format_type = sys.argv[4] if len(sys.argv) > 4 else "png"
    
    # Ensure output directory exists
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    print(f"Loading Kubernetes manifests from {kubernetes_dir}...")
    manifests = load_kubernetes_manifests(kubernetes_dir, environment)
    print(f"Found {len(manifests)} Kubernetes resources")
    
    # Generate ML Platform architecture diagram
    print("Generating ML Platform architecture diagram...")
    generate_ml_platform_diagram(output_dir, environment, format_type)
    
    # Generate detailed resource diagram
    if manifests:
        print("Generating detailed Kubernetes resource diagram...")
        generate_detailed_diagram(output_dir, environment, manifests, format_type)
    
    print(f"Diagrams generated in {output_dir}/")

if __name__ == "__main__":
    main()
EOF

    # Make Python script executable
    chmod +x "$python_script"
    
    # Run the Python script
    log_info "Running diagrams-as-code generation..."
    python3 "$python_script" "$KUBERNETES_DIR" "$ENVIRONMENT" "$OUTPUT_DIR" "$FORMAT"
    
    # Clean up the generated Python script
    rm "$python_script"
    
    # Return the generated file paths
    local generated_files=()
    for file in "${OUTPUT_DIR}/kubernetes-${ENVIRONMENT}-"*.{png,svg,pdf,py}; do
        if [[ -f "$file" ]]; then
            generated_files+=("$file")
        fi
    done
    
    if [ ${#generated_files[@]} -gt 0 ]; then
        log_success "Diagrams-as-code visualization generated"
        printf '%s\n' "${generated_files[@]}"
    else
        log_error "Failed to generate diagrams-as-code visualization"
        return 1
    fi
}

# Generate visualization using kubectl-graph
generate_kubectl_graph() {
    local output_file="${OUTPUT_DIR}/kubernetes-${ENVIRONMENT}-graph.${FORMAT}"
    
    log_info "Generating resource graph using kubectl-graph..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    if [[ "$USE_LIVE_CLUSTER" == true ]]; then
        # Use live cluster data
        kubectl graph all --namespace="$NAMESPACE" --output="$output_file"
    else
        log_warn "kubectl-graph requires a live cluster, switching to manifest analysis"
        return 1
    fi
    
    if [[ -f "$output_file" ]]; then
        log_success "kubectl-graph visualization generated: $output_file"
        echo "$output_file"
    else
        log_error "Failed to generate kubectl-graph visualization"
        return 1
    fi
}

# Generate namespace overview
generate_namespace_overview() {
    local output_file="${OUTPUT_DIR}/kubernetes-${ENVIRONMENT}-namespaces.md"
    
    log_info "Generating namespace overview..."
    
    cat > "$output_file" << EOF
# Kubernetes Namespace Overview - ${ENVIRONMENT}

**Generated:** $(date)
**Environment:** ${ENVIRONMENT}

## Namespace Summary

EOF

    if [[ "$USE_LIVE_CLUSTER" == true ]]; then
        echo "### Live Cluster Namespaces" >> "$output_file"
        echo '```' >> "$output_file"
        kubectl get namespaces -o wide >> "$output_file" 2>/dev/null || echo "Unable to fetch namespaces" >> "$output_file"
        echo '```' >> "$output_file"
        
        echo "" >> "$output_file"
        echo "### Resource Count by Namespace" >> "$output_file"
        echo '```' >> "$output_file"
        
        for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
            local pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
            local svc_count=$(kubectl get services -n "$ns" --no-headers 2>/dev/null | wc -l)
            local dep_count=$(kubectl get deployments -n "$ns" --no-headers 2>/dev/null | wc -l)
            echo "$ns: Pods($pod_count) Services($svc_count) Deployments($dep_count)" >> "$output_file"
        done
        
        echo '```' >> "$output_file"
    else
        echo "### Configured Namespaces (from manifests)" >> "$output_file"
        
        # Analyze manifest files for namespaces
        local namespaces=()
        if [[ -d "${KUBERNETES_DIR}/base" ]]; then
            namespaces+=($(grep -r "namespace:" "${KUBERNETES_DIR}/base" | grep -v "kustomization" | cut -d: -f3 | sort -u | sed 's/^ *//'))
        fi
        
        if [[ -d "${KUBERNETES_DIR}/overlays/${ENVIRONMENT}" ]]; then
            namespaces+=($(grep -r "namespace:" "${KUBERNETES_DIR}/overlays/${ENVIRONMENT}" | grep -v "kustomization" | cut -d: -f3 | sort -u | sed 's/^ *//'))
        fi
        
        # Remove duplicates and sort
        IFS=$'\n' sorted_namespaces=($(printf '%s\n' "${namespaces[@]}" | sort -u))
        
        echo '```' >> "$output_file"
        for ns in "${sorted_namespaces[@]}"; do
            echo "- $ns" >> "$output_file"
        done
        echo '```' >> "$output_file"
    fi

    cat >> "$output_file" << EOF

## Architecture Notes

### ML Platform Components
- **ml-platform**: Main application namespace
- **monitoring**: Observability stack (Prometheus, Grafana)
- **storage**: Storage services (MinIO, PostgreSQL, Redis)
- **argocd**: GitOps deployment automation

### Security Considerations
- Network policies isolate namespace communication
- RBAC controls limit service account permissions
- Pod security standards enforce secure container practices

### Monitoring
- All namespaces monitored by Prometheus
- Custom dashboards available in Grafana
- Log aggregation via centralized logging

---

**Note:** This overview is auto-generated. For detailed configuration, refer to the Kubernetes manifest files.
EOF

    log_success "Namespace overview generated: $output_file"
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
    log_info "Starting Kubernetes visualization for environment: $ENVIRONMENT"
    
    check_prerequisites
    validate_kubernetes_access
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local generated_files=()
    
    # Set up tools based on selection
    if [[ "$USE_DIAGRAMS_AS_CODE" == true ]]; then
        setup_python_environment
        
        log_info "Generating architecture diagrams using diagrams-as-code..."
        if readarray -t diagram_files < <(generate_diagrams_as_code); then
            generated_files+=("${diagram_files[@]}")
        fi
    fi
    
    if [[ "$USE_KUBECTL_GRAPH" == true ]]; then
        setup_kubectl_graph
        
        log_info "Generating resource graph using kubectl-graph..."
        if graph_file=$(generate_kubectl_graph); then
            generated_files+=("$graph_file")
        fi
    fi
    
    # Generate namespace overview
    if overview_file=$(generate_namespace_overview); then
        generated_files+=("$overview_file")
    fi
    
    # Display results
    echo ""
    log_success "Kubernetes visualization complete!"
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
    echo "  1. Review the generated diagrams to understand application architecture"
    echo "  2. Use the namespace overview for operational planning"
    echo "  3. Share visualizations with development teams"
    echo "  4. Update diagrams when Kubernetes configurations change"
}

# Execute main function
main "$@"