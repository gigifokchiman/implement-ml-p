# MCP Server Integration for AI-Assisted Infrastructure Visualization

**Model Context Protocol (MCP) integration for intelligent infrastructure analysis and visualization**

## 🎯 Overview

This guide sets up MCP servers for AI-assisted infrastructure visualization, enabling natural language queries and
automated diagram generation through Claude Desktop, VS Code, and other AI assistants.

## 🔧 MCP Servers for Infrastructure

### **1. HashiCorp Terraform MCP Server**

**Official Terraform integration with registry access**

```bash
# Install via VS Code or Claude Desktop
# Configuration in MCP settings
{
  "mcpServers": {
    "terraform": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-terraform"],
      "env": {
        "TERRAFORM_REGISTRY_TOKEN": "your_registry_token"
      }
    }
  }
}
```

**Capabilities:**

- Real-time Terraform module documentation
- Provider resource visualization
- Registry API integration
- Configuration validation

### **2. Kubernetes MCP Server**

**Community-driven Kubernetes cluster integration**

```bash
# Install kubernetes MCP server
npm install -g @kubernetes/mcp-server

# Configuration
{
  "mcpServers": {
    "kubernetes": {
      "command": "kubectl-mcp-server",
      "args": ["--kubeconfig", "~/.kube/config"],
      "env": {
        "KUBECONFIG": "~/.kube/config"
      }
    }
  }
}
```

**Capabilities:**

- Live cluster resource access
- Pod and service management
- Helm v3 support
- Read-only safety mode

### **3. Diagrams-as-Code MCP Server**

**Automated diagram generation from natural language**

```bash
# Custom MCP server for our visualization scripts
# Create wrapper script for our tools
{
  "mcpServers": {
    "ml-platform-viz": {
      "command": "python3",
      "args": ["/path/to/infrastructure/scripts/visualization/mcp-wrapper.py"],
      "cwd": "/path/to/infrastructure"
    }
  }
}
```

## 🚀 Setup Instructions

### **Step 1: Install MCP Servers**

#### **Claude Desktop Setup**

1. Open Claude Desktop settings
2. Navigate to MCP configuration
3. Add server configurations:

```json
{
  "mcpServers": {
    "terraform": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-terraform"]
    },
    "kubernetes": {
      "command": "kubectl-mcp-server",
      "args": ["--read-only"]
    },
    "ml-platform-viz": {
      "command": "python3",
      "args": ["scripts/visualization/mcp-wrapper.py"],
      "cwd": "/Users/chimanfok/workspaces/github/_data/implement-ml-p/infrastructure"
    }
  }
}
```

#### **VS Code Setup**

1. Install the MCP extension
2. Configure in VS Code settings:

```json
{
  "mcp.servers": [
    {
      "name": "terraform",
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-terraform"]
    },
    {
      "name": "kubernetes", 
      "command": "kubectl-mcp-server",
      "args": ["--namespace", "ml-platform"]
    }
  ]
}
```

### **Step 2: Create MCP Wrapper for ML Platform**

Create a custom MCP server wrapper for our visualization tools:

```python
#!/usr/bin/env python3
"""
MCP Server wrapper for ML Platform infrastructure visualization
Provides AI assistant access to our visualization tools
"""

import json
import subprocess
import sys
from pathlib import Path

class MLPlatformMCPServer:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        
    def handle_request(self, request):
        """Handle MCP requests for infrastructure visualization"""
        method = request.get('method')
        params = request.get('params', {})
        
        if method == 'tools/list':
            return self.list_tools()
        elif method == 'tools/call':
            return self.call_tool(params)
        else:
            return {"error": f"Unknown method: {method}"}
    
    def list_tools(self):
        """List available visualization tools"""
        return {
            "tools": [
                {
                    "name": "visualize_terraform",
                    "description": "Generate Terraform infrastructure visualizations",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "environment": {"type": "string", "default": "local"},
                            "format": {"type": "string", "default": "png"},
                            "tool": {"type": "string", "enum": ["rover", "graph", "inframap"]}
                        }
                    }
                },
                {
                    "name": "visualize_kubernetes", 
                    "description": "Generate Kubernetes application visualizations",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "environment": {"type": "string", "default": "local"},
                            "namespace": {"type": "string", "default": "ml-platform"},
                            "format": {"type": "string", "default": "png"}
                        }
                    }
                },
                {
                    "name": "visualize_full_infrastructure",
                    "description": "Generate comprehensive infrastructure visualization suite",
                    "inputSchema": {
                        "type": "object", 
                        "properties": {
                            "environment": {"type": "string", "default": "local"},
                            "format": {"type": "string", "default": "png"},
                            "open_browser": {"type": "boolean", "default": true}
                        }
                    }
                }
            ]
        }
    
    def call_tool(self, params):
        """Execute visualization tools"""
        tool_name = params.get('name')
        arguments = params.get('arguments', {})
        
        try:
            if tool_name == 'visualize_terraform':
                return self.run_terraform_viz(arguments)
            elif tool_name == 'visualize_kubernetes':
                return self.run_kubernetes_viz(arguments)
            elif tool_name == 'visualize_full_infrastructure':
                return self.run_full_viz(arguments)
            else:
                return {"error": f"Unknown tool: {tool_name}"}
        except Exception as e:
            return {"error": f"Tool execution failed: {str(e)}"}
    
    def run_terraform_viz(self, args):
        """Run Terraform visualization"""
        cmd = [
            str(self.script_dir / "terraform-visualize.sh"),
            "-e", args.get('environment', 'local'),
            "-f", args.get('format', 'png')
        ]
        
        if args.get('tool') == 'rover':
            cmd.append('--use-rover')
        elif args.get('tool') == 'inframap':
            cmd.append('--use-inframap')
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"Terraform visualization completed\n\nOutput:\n{result.stdout}\n\nErrors:\n{result.stderr}"
                }
            ]
        }
    
    def run_kubernetes_viz(self, args):
        """Run Kubernetes visualization"""
        cmd = [
            str(self.script_dir / "kubernetes-visualize.sh"),
            "-e", args.get('environment', 'local'),
            "-n", args.get('namespace', 'ml-platform'),
            "-f", args.get('format', 'png')
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        return {
            "content": [
                {
                    "type": "text", 
                    "text": f"Kubernetes visualization completed\n\nOutput:\n{result.stdout}\n\nErrors:\n{result.stderr}"
                }
            ]
        }
    
    def run_full_viz(self, args):
        """Run full infrastructure visualization suite"""
        cmd = [
            str(self.script_dir / "visualize-infrastructure.sh"),
            "-e", args.get('environment', 'local'),
            "-f", args.get('format', 'png')
        ]
        
        if args.get('open_browser', True):
            cmd.append('-o')
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"Full infrastructure visualization completed\n\nOutput:\n{result.stdout}\n\nGenerated comprehensive visualization suite with interactive navigation."
                }
            ]
        }

def main():
    """Main MCP server loop"""
    server = MLPlatformMCPServer()
    
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
                
            request = json.loads(line.strip())
            response = server.handle_request(request)
            
            print(json.dumps(response))
            sys.stdout.flush()
            
        except Exception as e:
            error_response = {"error": f"Server error: {str(e)}"}
            print(json.dumps(error_response))
            sys.stdout.flush()

if __name__ == "__main__":
    main()
```

### **Step 3: Test MCP Integration**

#### **Natural Language Queries**

Once configured, you can use natural language with your AI assistant:

```
"Show me the Terraform dependency graph for the production environment"
→ Automatically runs terraform-visualize.sh -e prod

"Generate a Kubernetes architecture diagram for the ml-platform namespace" 
→ Runs kubernetes-visualize.sh -n ml-platform

"Create a complete infrastructure visualization suite with SVG output"
→ Runs visualize-infrastructure.sh -f svg -o
```

#### **Verification Commands**

```bash
# Test MCP server connection
echo '{"method": "tools/list"}' | python3 scripts/visualization/mcp-wrapper.py

# Verify Claude Desktop integration
# Open Claude Desktop and ask: "What visualization tools are available?"
```

## 🎯 Usage Examples

### **AI-Assisted Architecture Analysis**

**Query:** *"Analyze the dependencies between our ML platform services and generate a visual diagram"*

**AI Response:** The assistant will:

1. Use the Kubernetes MCP server to fetch live cluster data
2. Call the visualization tools to generate diagrams
3. Analyze the architecture and provide insights
4. Suggest optimizations based on the visual analysis

### **Interactive Infrastructure Exploration**

**Query:** *"Show me how data flows through our infrastructure from user request to ML model prediction"*

**AI Response:** The assistant will:

1. Generate both Terraform and Kubernetes visualizations
2. Create a unified flow diagram
3. Explain the data path with visual references
4. Highlight potential bottlenecks or security concerns

### **Automated Documentation Updates**

**Query:** *"Generate updated architecture diagrams for all environments and explain what changed"*

**AI Response:** The assistant will:

1. Run visualization for local, dev, staging, and prod
2. Compare with previous versions (if available)
3. Highlight architectural differences
4. Generate updated documentation

## 🔒 Security Considerations

### **Read-Only Access**

- Configure MCP servers with read-only permissions
- Use separate service accounts with minimal privileges
- Enable audit logging for MCP server access

### **Credential Management**

```bash
# Use environment variables for sensitive tokens
export TERRAFORM_REGISTRY_TOKEN="your_token"
export KUBECONFIG="~/.kube/config"

# Restrict file permissions
chmod 600 ~/.kube/config
```

### **Network Security**

- MCP servers run locally, no external network access
- Kubernetes MCP server uses existing kubeconfig
- No secrets transmitted over network

## 🚀 Advanced Features

### **Custom Prompts for Visualization**

Create specialized prompts for common visualization tasks:

```
"Infrastructure Health Check": 
- Generate current state diagrams
- Compare with baseline architecture
- Identify configuration drift
- Suggest remediation steps

"Security Review":
- Visualize network policies and RBAC
- Highlight potential security gaps
- Generate compliance documentation
- Recommend security improvements
```

### **Integration with CI/CD**

```yaml
# GitHub Actions example
- name: Generate and Commit Diagrams
  run: |
    # Use MCP server to generate diagrams
    echo '{"method": "tools/call", "params": {"name": "visualize_full_infrastructure", "arguments": {"environment": "prod"}}}' | \
    python3 scripts/visualization/mcp-wrapper.py
    
    # Commit updated diagrams
    git add docs/diagrams/
    git commit -m "🔄 Auto-update infrastructure diagrams"
```

## 🔧 Troubleshooting

### **Common Issues**

**MCP Server Not Found:**

```bash
# Verify installation
npx @anthropic/mcp-server-terraform --version

# Check PATH
echo $PATH | grep -o '\S*\.local/bin\S*'
```

**Permissions Error:**

```bash
# Fix script permissions
chmod +x scripts/visualization/*.sh

# Fix Python script permissions  
chmod +x scripts/visualization/mcp-wrapper.py
```

**Kubernetes Access:**

```bash
# Test kubectl access
kubectl cluster-info

# Verify namespace access
kubectl get pods -n ml-platform
```

## 📚 Resources

- **HashiCorp Terraform MCP**: [GitHub Repository](https://github.com/anthropics/mcp-server-terraform)
- **Kubernetes MCP**: [Community Server](https://github.com/kubernetes/mcp-server-kubernetes)
- **MCP Protocol**: [Specification](https://spec.modelcontextprotocol.io/)
- **Claude Desktop**: [MCP Configuration Guide](https://docs.anthropic.com/claude/docs/mcp)

---

**Next Steps:**

1. Configure MCP servers in your AI assistant
2. Test with simple visualization queries
3. Create custom prompts for your workflow
4. Integrate with development processes

This setup transforms infrastructure visualization from manual script execution to intelligent, conversational analysis
with your AI assistant.
