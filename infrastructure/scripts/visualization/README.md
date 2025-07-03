# Infrastructure Visualization Suite

**Automated infrastructure visualization from IaC configurations using modern tools and AI-assisted analysis**

## 🎯 Overview

Complete visualization solution for ML Platform infrastructure combining:

- **Terraform**: Infrastructure dependency graphs using terraform graph, Rover, and InfraMap
- **Kubernetes**: Application architecture using diagrams-as-code and kubectl integration
- **ArgoCD**: GitOps workflow and application dependency visualization
- **MCP Integration**: AI-assisted visualization through Model Context Protocol

## 🚀 Quick Start

```bash
# Generate complete infrastructure visualization suite
./visualize-infrastructure.sh

# Terraform infrastructure only
./terraform-visualize.sh -e prod -f svg

# Kubernetes applications only  
./kubernetes-visualize.sh -e local --live-cluster

# ArgoCD GitOps workflow
./argocd-visualize.sh -e staging -o
```

## 📊 Visualization Tools

### **1. Terraform Infrastructure Visualization**

**Script:** `terraform-visualize.sh`

**Tools Used:**

- **terraform graph + GraphViz**: Basic dependency graphs
- **Rover**: Interactive HTML visualizations via Docker (with ARM64 compatibility)
- **Enhanced Graph**: Custom interactive visualizations (ARM64-native fallback)
- **InfraMap**: Simplified, provider-optimized diagrams
- **Custom documentation**: Auto-generated architecture docs

**Features:**

- Multi-environment support (local, dev, staging, prod)
- Multiple output formats (PNG, SVG, PDF, HTML)
- Interactive exploration with Rover
- Comprehensive documentation generation

**Usage:**

```bash
# Basic usage
./terraform-visualize.sh

# Production environment with Rover
./terraform-visualize.sh -e prod --use-rover -o

# Simplified visualization with InfraMap
./terraform-visualize.sh --use-inframap -f svg
```

### **2. Kubernetes Application Visualization**

**Script:** `kubernetes-visualize.sh`

**Tools Used:**

- **diagrams-as-code**: Python library for architectural diagrams
- **kubectl**: Live cluster data integration
- **Custom analysis**: Namespace and resource dependency mapping

**Features:**

- Live cluster or manifest-based visualization
- ML Platform-specific architecture diagrams
- Namespace overview and resource mapping
- Cross-platform diagram generation

**Usage:**

```bash
# Live cluster visualization
./kubernetes-visualize.sh --live-cluster -n ml-platform

# Manifest-based analysis
./kubernetes-visualize.sh -e prod -f pdf

# Specific namespace focus
./kubernetes-visualize.sh -n argocd --live-cluster
```

### **3. ArgoCD GitOps Visualization**

**Script:** `argocd-visualize.sh`

**Tools Used:**

- **diagrams-as-code**: GitOps workflow diagrams
- **kubectl + ArgoCD API**: Live application status
- **Custom analysis**: Application dependency mapping

**Features:**

- GitOps workflow visualization
- Application sync status overview
- Dependency analysis between applications
- Integration with live ArgoCD instances

**Usage:**

```bash
# GitOps workflow visualization
./argocd-visualize.sh --live-cluster

# Application status overview
./argocd-visualize.sh -e prod -f svg -o

# Manifest-only analysis
./argocd-visualize.sh --manifests-only
```

### **4. Unified Infrastructure Suite**

**Script:** `visualize-infrastructure.sh`

**Comprehensive solution combining all visualization tools**

**Features:**

- Cross-platform architecture overview
- Interactive HTML navigation
- Unified documentation generation
- Environment comparison matrices

**Usage:**

```bash
# Complete visualization suite
./visualize-infrastructure.sh -e prod -o

# Terraform infrastructure only
./visualize-infrastructure.sh --terraform-only

# Kubernetes applications only
./visualize-infrastructure.sh --kubernetes-only
```

## 🤖 AI-Assisted Visualization (MCP Integration)

### **Model Context Protocol Server**

**Script:** `mcp-wrapper.py`
**Setup Guide:** `../docs/setup/mcp-visualization-setup.md`

**Capabilities:**

- Natural language infrastructure queries
- Automated diagram generation via AI assistants
- Integration with Claude Desktop, VS Code, and other AI tools
- Intelligent architecture analysis and recommendations

**Example Queries:**

```
"Generate a complete infrastructure visualization for production"
"Show me the Kubernetes application dependencies for the ml-platform namespace"
"Analyze the security posture of our local development environment"
"Create GitOps workflow diagrams for all environments"
```

**Setup:**

```json
{
  "mcpServers": {
    "ml-platform-viz": {
      "command": "python3",
      "args": ["scripts/visualization/mcp-wrapper.py"],
      "cwd": "/path/to/infrastructure"
    }
  }
}
```

## 📁 Generated Outputs

### **Directory Structure**

```
docs/diagrams/
├── index.html                          # Interactive navigation
├── terraform/                          # Infrastructure visualizations
│   ├── terraform-{env}-graph.{format}
│   ├── terraform-{env}-rover.html
│   └── terraform-{env}-docs.md
├── kubernetes/                         # Application visualizations  
│   ├── kubernetes-{env}-architecture.{format}
│   ├── kubernetes-{env}-detailed.{format}
│   └── kubernetes-{env}-namespaces.md
├── gitops/                            # GitOps visualizations
│   ├── argocd-{env}-gitops-flow.{format}
│   ├── argocd-{env}-app-status.{format}
│   └── argocd-{env}-overview.md
└── unified/                           # Cross-platform documentation
    └── architecture-overview.md
```

### **Interactive Navigation**

Generated `index.html` provides:

- Visual navigation of all diagrams
- Environment switching
- Direct links to documentation
- Mobile-friendly interface

## 🔧 Prerequisites

### **Required Tools**

```bash
# Core requirements
terraform >= 1.0
kubectl >= 1.25
python3 >= 3.8
graphviz (dot command)

# Optional enhancements
docker (for Rover - with ARM64 platform override support)
argocd CLI (for enhanced ArgoCD features)
```

### **Installation**

```bash
# macOS
brew install terraform kubectl python3 graphviz docker

# Ubuntu
apt-get install terraform kubectl python3 graphviz docker.io

# Python dependencies
pip3 install diagrams graphviz --user
```

## 🎨 Visualization Features

### **Multi-Format Output**

- **PNG**: High-quality raster images
- **SVG**: Scalable vector graphics
- **PDF**: Print-ready documentation
- **HTML**: Interactive exploration (Rover)

### **Environment Support**

- **local**: Kind cluster development
- **dev**: AWS development environment
- **staging**: Pre-production validation
- **prod**: Production deployment

### **Cross-Platform Integration**

- **Layer 1 (Terraform)**: Infrastructure foundations
- **Layer 2 (Kubernetes)**: Application deployments
- **GitOps (ArgoCD)**: Continuous delivery workflow

## 🔒 Security Considerations

### **Safe Defaults**

- Read-only cluster access by default
- No secrets or credentials in diagrams
- Temporary file cleanup
- Secure Docker container execution

### **MCP Server Security**

- Local execution only
- No external network access
- Minimal file system permissions
- Audit logging support

## 🚀 Advanced Usage

### **CI/CD Integration**

```yaml
# GitHub Actions example
- name: Generate Infrastructure Diagrams
  run: |
    ./scripts/visualization/visualize-infrastructure.sh -e ${{ matrix.environment }}
    git add docs/diagrams/
    git commit -m "📊 Update infrastructure diagrams"
```

### **Custom Diagram Themes**

```python
# Extend diagrams-as-code with custom themes
from diagrams import Diagram
from diagrams.custom import Custom

# Use custom icons and styling
with Diagram("ML Platform", direction="TB"):
    # Custom themed diagrams
```

### **Automated Documentation**

```bash
# Schedule regular diagram updates
crontab -e
# 0 2 * * 1 /path/to/visualize-infrastructure.sh --cleanup
```

## 🔧 Troubleshooting

### **Common Issues**

**Permission Denied:**

```bash
chmod +x scripts/visualization/*.sh
```

**Missing Dependencies:**

```bash
# Check prerequisites
./visualize-infrastructure.sh --help
pip3 install diagrams graphviz --user
```

**Docker Issues:**

```bash
# For Rover visualization
docker info
docker pull im2nguyen/rover:latest

# ARM64 (Apple Silicon) compatibility
docker run --platform linux/amd64 --rm \
  -v $(pwd):/src -p 9000:9000 \
  im2nguyen/rover -tfPath /src
```

**Rover ARM64 Issues:**

```bash
# If Rover fails on ARM64, use enhanced graph fallback
./terraform-graph-enhanced.sh -e local -f png

# Or run Rover with platform override
docker run --platform linux/amd64 --rm \
  -v $(pwd):/src -p 9000:9000 \
  im2nguyen/rover -tfPath /src
```

**Kubernetes Access:**

```bash
kubectl cluster-info
kubectl get namespaces
```

### **Debug Mode**

```bash
# Enable verbose output
export DEBUG=1
./visualize-infrastructure.sh
```

## 📚 Documentation

### **Generated Documentation**

- Infrastructure architecture overviews
- Environment comparison matrices
- Security configuration summaries
- Operational runbooks

### **Integration Guides**

- MCP server setup for AI assistants
- CI/CD pipeline integration
- Custom visualization development
- Team collaboration workflows

## 🌟 Key Benefits

1. **🎯 Automated Documentation**: Keep architecture diagrams current
2. **🤖 AI Integration**: Natural language infrastructure queries
3. **🔄 Multi-Tool Support**: Best-in-class visualization tools
4. **📊 Comprehensive Coverage**: Infrastructure + Applications + GitOps
5. **🎨 Professional Output**: Publication-ready diagrams
6. **⚡ Fast Iteration**: Quick updates for changing infrastructure

---

**Next Steps:**

1. Run `./visualize-infrastructure.sh` to generate your first visualization suite
2. Set up MCP integration for AI-assisted analysis
3. Integrate with your CI/CD pipeline for automated updates
4. Share visualizations with your team for architectural discussions

This visualization suite transforms static IaC configurations into dynamic, interactive documentation that evolves with
your infrastructure.
