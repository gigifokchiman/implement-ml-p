#!/bin/bash
# Enhanced Terraform Graph Visualization
# Alternative to Rover for ARM64 compatibility and better visualization

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

# Parse command line arguments
usage() {
    echo "Enhanced Terraform Graph Visualization"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment (local, dev, staging, prod)"
    echo "  -f, --format FORMAT      Output format (png, svg, pdf)"
    echo "  --output-dir DIR         Output directory"
    echo "  --help, -h              Show this help"
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
            exit 1
            ;;
    esac
done

# Generate enhanced graph visualization
generate_enhanced_graph() {
    local env_dir="${TERRAFORM_DIR}/environments/${ENVIRONMENT}"
    local base_name="terraform-${ENVIRONMENT}-enhanced"
    
    log_info "Generating enhanced Terraform graph visualization..."
    
    cd "$env_dir"
    mkdir -p "$OUTPUT_DIR"
    
    # Check if terraform is initialized
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init -upgrade
    fi
    
    # Generate graph with enhanced styling
    local graph_file="${OUTPUT_DIR}/${base_name}.dot"
    
    log_info "Generating Terraform dependency graph..."
    terraform graph > "$graph_file"
    
    # Enhance the DOT file with better styling
    local styled_graph="${OUTPUT_DIR}/${base_name}-styled.dot"
    
    cat > "$styled_graph" << 'EOF'
digraph {
    // Graph attributes
    bgcolor="white";
    rankdir="TB";
    splines="ortho";
    nodesep="0.8";
    ranksep="1.2";
    fontname="Arial";
    fontsize="14";
    
    // Default node style
    node [
        shape="box",
        style="rounded,filled",
        fillcolor="lightblue",
        fontname="Arial",
        fontsize="12",
        margin="0.2,0.1"
    ];
    
    // Default edge style
    edge [
        color="gray60",
        fontname="Arial",
        fontsize="10",
        arrowsize="0.8"
    ];
    
EOF
    
    # Process the original graph and enhance it
    tail -n +2 "$graph_file" | head -n -1 | while IFS= read -r line; do
        if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*-\>[[:space:]]*\"([^\"]+)\" ]]; then
            local from="${BASH_REMATCH[1]}"
            local to="${BASH_REMATCH[2]}"
            
            # Color nodes based on resource type
            local from_color="lightblue"
            local to_color="lightblue"
            
            case "$from" in
                *provider*) from_color="lightgreen" ;;
                *data*) from_color="lightyellow" ;;
                *resource*) from_color="lightcoral" ;;
                *module*) from_color="lightpink" ;;
                *var*) from_color="lightgray" ;;
                *output*) from_color="lightsteelblue" ;;
            esac
            
            case "$to" in
                *provider*) to_color="lightgreen" ;;
                *data*) to_color="lightyellow" ;;
                *resource*) to_color="lightcoral" ;;
                *module*) to_color="lightpink" ;;
                *var*) to_color="lightgray" ;;
                *output*) to_color="lightsteelblue" ;;
            esac
            
            echo "    \"$from\" [fillcolor=\"$from_color\"];" >> "$styled_graph"
            echo "    \"$to\" [fillcolor=\"$to_color\"];" >> "$styled_graph"
            echo "    \"$from\" -> \"$to\";" >> "$styled_graph"
        else
            echo "    $line" >> "$styled_graph"
        fi
    done
    
    echo "}" >> "$styled_graph"
    
    # Generate output in requested format
    local output_file="${OUTPUT_DIR}/${base_name}.${FORMAT}"
    
    case "$FORMAT" in
        png)
            dot -Tpng -Gdpi=300 "$styled_graph" -o "$output_file"
            ;;
        svg)
            dot -Tsvg "$styled_graph" -o "$output_file"
            ;;
        pdf)
            dot -Tpdf "$styled_graph" -o "$output_file"
            ;;
        *)
            log_error "Unsupported format: $FORMAT"
            return 1
            ;;
    esac
    
    # Generate interactive HTML version
    local html_file="${OUTPUT_DIR}/${base_name}.html"
    generate_interactive_html "$styled_graph" "$html_file"
    
    # Clean up temporary files
    rm -f "$graph_file" "$styled_graph"
    
    log_success "Enhanced graph visualization generated: $output_file"
    log_success "Interactive HTML version: $html_file"
    
    echo "$output_file"
}

# Generate interactive HTML visualization
generate_interactive_html() {
    local dot_file="$1"
    local html_file="$2"
    
    log_info "Generating interactive HTML visualization..."
    
    # Convert DOT to SVG for embedding
    local svg_content=$(dot -Tsvg "$dot_file" | tail -n +7)  # Skip XML declaration
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terraform Infrastructure - ${ENVIRONMENT}</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            color: white;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
            font-size: 1.1em;
        }
        
        .container {
            max-width: 1400px;
            margin: 20px auto;
            padding: 0 20px;
        }
        
        .controls {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .control-group {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        button {
            background: #667eea;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            transition: background 0.3s;
        }
        
        button:hover {
            background: #5a6fd8;
        }
        
        .graph-container {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            overflow: auto;
            max-height: 80vh;
        }
        
        .graph-svg {
            width: 100%;
            height: auto;
            cursor: grab;
        }
        
        .graph-svg:active {
            cursor: grabbing;
        }
        
        .legend {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-top: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .legend h3 {
            margin-top: 0;
            color: #333;
        }
        
        .legend-item {
            display: inline-block;
            margin: 5px 15px 5px 0;
            padding: 5px 10px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
        }
        
        .legend-provider { background: lightgreen; }
        .legend-data { background: lightyellow; }
        .legend-resource { background: lightcoral; }
        .legend-module { background: lightpink; }
        .legend-variable { background: lightgray; }
        .legend-output { background: lightsteelblue; }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .stat-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Terraform Infrastructure Visualization</h1>
        <p>Environment: ${ENVIRONMENT} | Generated: $(date)</p>
    </div>
    
    <div class="container">
        <div class="controls">
            <div class="control-group">
                <button onclick="zoomIn()">🔍 Zoom In</button>
                <button onclick="zoomOut()">🔍 Zoom Out</button>
                <button onclick="resetZoom()">🔄 Reset Zoom</button>
            </div>
            <div class="control-group">
                <button onclick="fitToScreen()">📐 Fit to Screen</button>
                <button onclick="downloadSVG()">💾 Download SVG</button>
            </div>
        </div>
        
        <div class="graph-container">
            <div class="graph-svg" id="graphSVG">
                $svg_content
            </div>
        </div>
        
        <div class="legend">
            <h3>🏷️ Resource Types</h3>
            <div class="legend-item legend-provider">Provider</div>
            <div class="legend-item legend-data">Data Source</div>
            <div class="legend-item legend-resource">Resource</div>
            <div class="legend-item legend-module">Module</div>
            <div class="legend-item legend-variable">Variable</div>
            <div class="legend-item legend-output">Output</div>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number" id="nodeCount">-</div>
                <div class="stat-label">Nodes</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="edgeCount">-</div>
                <div class="stat-label">Dependencies</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">${ENVIRONMENT}</div>
                <div class="stat-label">Environment</div>
            </div>
        </div>
    </div>
    
    <script>
        let scale = 1;
        const svgContainer = document.getElementById('graphSVG');
        const svg = svgContainer.querySelector('svg');
        
        if (svg) {
            // Set initial viewBox
            const bbox = svg.getBBox();
            svg.setAttribute('viewBox', \`\${bbox.x} \${bbox.y} \${bbox.width} \${bbox.height}\`);
            
            // Calculate stats
            const nodes = svg.querySelectorAll('g.node');
            const edges = svg.querySelectorAll('g.edge');
            
            document.getElementById('nodeCount').textContent = nodes.length;
            document.getElementById('edgeCount').textContent = edges.length;
            
            // Add hover effects
            nodes.forEach(node => {
                node.addEventListener('mouseenter', function() {
                    this.style.opacity = '0.8';
                    this.style.transform = 'scale(1.05)';
                });
                
                node.addEventListener('mouseleave', function() {
                    this.style.opacity = '1';
                    this.style.transform = 'scale(1)';
                });
            });
        }
        
        function zoomIn() {
            scale *= 1.2;
            updateZoom();
        }
        
        function zoomOut() {
            scale /= 1.2;
            updateZoom();
        }
        
        function resetZoom() {
            scale = 1;
            updateZoom();
        }
        
        function updateZoom() {
            if (svg) {
                svg.style.transform = \`scale(\${scale})\`;
            }
        }
        
        function fitToScreen() {
            if (svg) {
                const containerRect = svgContainer.getBoundingClientRect();
                const svgRect = svg.getBoundingClientRect();
                const scaleX = containerRect.width / svgRect.width;
                const scaleY = containerRect.height / svgRect.height;
                scale = Math.min(scaleX, scaleY) * 0.9;
                updateZoom();
            }
        }
        
        function downloadSVG() {
            if (svg) {
                const svgData = new XMLSerializer().serializeToString(svg);
                const blob = new Blob([svgData], {type: 'image/svg+xml'});
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = 'terraform-${ENVIRONMENT}-graph.svg';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            }
        }
        
        // Pan functionality
        let isPanning = false;
        let startPoint = { x: 0, y: 0 };
        let currentTranslate = { x: 0, y: 0 };
        
        svgContainer.addEventListener('mousedown', function(e) {
            isPanning = true;
            startPoint = { x: e.clientX, y: e.clientY };
        });
        
        document.addEventListener('mousemove', function(e) {
            if (!isPanning) return;
            
            const dx = e.clientX - startPoint.x;
            const dy = e.clientY - startPoint.y;
            
            currentTranslate.x += dx;
            currentTranslate.y += dy;
            
            if (svg) {
                svg.style.transform = \`scale(\${scale}) translate(\${currentTranslate.x}px, \${currentTranslate.y}px)\`;
            }
            
            startPoint = { x: e.clientX, y: e.clientY };
        });
        
        document.addEventListener('mouseup', function() {
            isPanning = false;
        });
        
        // Initialize
        fitToScreen();
    </script>
</body>
</html>
EOF
}

# Main execution
main() {
    log_info "Starting enhanced Terraform graph visualization for environment: $ENVIRONMENT"
    
    # Check prerequisites
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found"
        exit 1
    fi
    
    if ! command -v dot &> /dev/null; then
        log_error "Graphviz not found. Install with: ./helpers/install-graphviz.sh"
        exit 1
    fi
    
    # Generate visualization
    if output_file=$(generate_enhanced_graph); then
        log_success "Enhanced Terraform visualization complete!"
        echo "Generated files:"
        echo "  📊 Graph: $output_file"
        echo "  🌐 Interactive: ${output_file%.*}.html"
    else
        log_error "Failed to generate visualization"
        exit 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi