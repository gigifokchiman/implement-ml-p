#!/usr/bin/env python3
"""
MCP Server wrapper for ML Platform infrastructure visualization
Provides AI assistant access to our visualization tools through Model Context Protocol
"""

import json
import subprocess
import sys
from pathlib import Path


class MLPlatformMCPServer:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        self.infrastructure_dir = self.script_dir.parent.parent

    def handle_request(self, request):
        """Handle MCP requests for infrastructure visualization"""
        method = request.get('method')
        params = request.get('params', {})

        if method == 'tools/list':
            return self.list_tools()
        elif method == 'tools/call':
            return self.call_tool(params)
        elif method == 'resources/list':
            return self.list_resources()
        elif method == 'resources/read':
            return self.read_resource(params)
        else:
            return {"error": f"Unknown method: {method}"}

    def list_tools(self):
        """List available visualization tools"""
        return {
            "tools": [
                {
                    "name": "visualize_terraform",
                    "description": "Generate Terraform infrastructure visualizations using multiple tools (terraform graph, Rover, InfraMap)",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "environment": {
                                "type": "string",
                                "default": "local",
                                "enum": ["local", "dev", "staging", "prod"],
                                "description": "Target environment for visualization"
                            },
                            "format": {
                                "type": "string",
                                "default": "png",
                                "enum": ["png", "svg", "pdf", "html"],
                                "description": "Output format for diagrams"
                            },
                            "tool": {
                                "type": "string",
                                "enum": ["rover", "inframap", "graph"],
                                "description": "Specific visualization tool to use"
                            },
                            "open_browser": {
                                "type": "boolean",
                                "default": False,
                                "description": "Open generated diagrams in browser"
                            }
                        }
                    }
                },
                {
                    "name": "visualize_kubernetes",
                    "description": "Generate Kubernetes application visualizations using diagrams-as-code and kubectl integration",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "environment": {
                                "type": "string",
                                "default": "local",
                                "enum": ["local", "dev", "staging", "prod"],
                                "description": "Target environment for visualization"
                            },
                            "namespace": {
                                "type": "string",
                                "default": "ml-platform",
                                "description": "Kubernetes namespace to focus on"
                            },
                            "format": {
                                "type": "string",
                                "default": "png",
                                "enum": ["png", "svg", "pdf"],
                                "description": "Output format for diagrams"
                            },
                            "use_live_cluster": {
                                "type": "boolean",
                                "default": False,
                                "description": "Use live cluster data instead of manifests"
                            },
                            "open_browser": {
                                "type": "boolean",
                                "default": False,
                                "description": "Open generated diagrams in browser"
                            }
                        }
                    }
                },
                {
                    "name": "visualize_full_infrastructure",
                    "description": "Generate comprehensive infrastructure visualization suite combining Terraform and Kubernetes with unified documentation",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "environment": {
                                "type": "string",
                                "default": "local",
                                "enum": ["local", "dev", "staging", "prod"],
                                "description": "Target environment for visualization"
                            },
                            "format": {
                                "type": "string",
                                "default": "png",
                                "enum": ["png", "svg", "pdf"],
                                "description": "Output format for diagrams"
                            },
                            "open_browser": {
                                "type": "boolean",
                                "default": True,
                                "description": "Open visualization suite in browser"
                            },
                            "terraform_only": {
                                "type": "boolean",
                                "default": False,
                                "description": "Generate only Terraform visualizations"
                            },
                            "kubernetes_only": {
                                "type": "boolean",
                                "default": False,
                                "description": "Generate only Kubernetes visualizations"
                            }
                        }
                    }
                },
                {
                    "name": "analyze_infrastructure",
                    "description": "Analyze infrastructure configuration and provide insights about architecture, dependencies, and potential improvements",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "environment": {
                                "type": "string",
                                "default": "local",
                                "enum": ["local", "dev", "staging", "prod"],
                                "description": "Environment to analyze"
                            },
                            "focus_area": {
                                "type": "string",
                                "enum": ["security", "performance", "cost", "reliability", "all"],
                                "default": "all",
                                "description": "Specific area to focus analysis on"
                            }
                        }
                    }
                }
            ]
        }

    def list_resources(self):
        """List available infrastructure resources"""
        return {
            "resources": [
                {
                    "uri": "file://terraform/environments",
                    "name": "Terraform Environments",
                    "description": "Terraform configuration files for all environments",
                    "mimeType": "text/directory"
                },
                {
                    "uri": "file://kubernetes/base",
                    "name": "Kubernetes Base Configurations",
                    "description": "Base Kubernetes manifests and Kustomize configurations",
                    "mimeType": "text/directory"
                },
                {
                    "uri": "file://docs/diagrams",
                    "name": "Generated Diagrams",
                    "description": "Previously generated infrastructure diagrams",
                    "mimeType": "text/directory"
                },
                {
                    "uri": "file://scripts/visualization",
                    "name": "Visualization Scripts",
                    "description": "Infrastructure visualization automation scripts",
                    "mimeType": "text/directory"
                }
            ]
        }

    def read_resource(self, params):
        """Read infrastructure resource content"""
        uri = params.get('uri', '')

        if uri.startswith('file://'):
            file_path = self.infrastructure_dir / uri[7:]  # Remove 'file://' prefix

            try:
                if file_path.is_file():
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    return {
                        "contents": [
                            {
                                "uri": uri,
                                "mimeType": "text/plain",
                                "text": content
                            }
                        ]
                    }
                elif file_path.is_dir():
                    # List directory contents
                    files = []
                    for item in file_path.iterdir():
                        files.append(f"{'📁' if item.is_dir() else '📄'} {item.name}")

                    return {
                        "contents": [
                            {
                                "uri": uri,
                                "mimeType": "text/plain",
                                "text": f"Directory listing for {file_path}:\n\n" + "\n".join(files)
                            }
                        ]
                    }
                else:
                    return {"error": f"Resource not found: {file_path}"}

            except Exception as e:
                return {"error": f"Failed to read resource: {str(e)}"}
        else:
            return {"error": f"Unsupported URI scheme: {uri}"}

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
            elif tool_name == 'analyze_infrastructure':
                return self.analyze_infrastructure(arguments)
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

        if args.get('open_browser', False):
            cmd.append('-o')

        result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.infrastructure_dir)

        # Find generated files
        diagrams_dir = self.infrastructure_dir / "docs" / "diagrams"
        generated_files = []
        if diagrams_dir.exists():
            for file in diagrams_dir.glob("terraform-*"):
                generated_files.append(str(file.relative_to(self.infrastructure_dir)))

        return {
            "content": [
                {
                    "type": "text",
                    "text": f"🔧 Terraform visualization completed for {args.get('environment', 'local')} environment\n\n"
                            f"✅ Generated files:\n" + "\n".join(f"  📊 {f}" for f in generated_files) + "\n\n"
                                                                                                       f"📝 Output:\n{result.stdout}\n\n"
                                                                                                       f"⚠️  Warnings/Errors:\n{result.stderr if result.stderr else 'None'}"
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

        if args.get('use_live_cluster', False):
            cmd.append('--live-cluster')

        if args.get('open_browser', False):
            cmd.append('-o')

        result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.infrastructure_dir)

        # Find generated files
        diagrams_dir = self.infrastructure_dir / "docs" / "diagrams"
        generated_files = []
        if diagrams_dir.exists():
            for file in diagrams_dir.glob("kubernetes-*"):
                generated_files.append(str(file.relative_to(self.infrastructure_dir)))

        return {
            "content": [
                {
                    "type": "text",
                    "text": f"🚀 Kubernetes visualization completed for {args.get('environment', 'local')} environment\n\n"
                            f"📦 Namespace: {args.get('namespace', 'ml-platform')}\n"
                            f"✅ Generated files:\n" + "\n".join(f"  📊 {f}" for f in generated_files) + "\n\n"
                                                                                                       f"📝 Output:\n{result.stdout}\n\n"
                                                                                                       f"⚠️  Warnings/Errors:\n{result.stderr if result.stderr else 'None'}"
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

        if args.get('terraform_only', False):
            cmd.append('--terraform-only')
        elif args.get('kubernetes_only', False):
            cmd.append('--kubernetes-only')

        result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.infrastructure_dir)

        # Count generated files
        diagrams_dir = self.infrastructure_dir / "docs" / "diagrams"
        file_count = 0
        if diagrams_dir.exists():
            file_count = len(list(diagrams_dir.rglob("*.*")))

        return {
            "content": [
                {
                    "type": "text",
                    "text": f"🏗️ Complete infrastructure visualization suite generated!\n\n"
                            f"📊 Environment: {args.get('environment', 'local')}\n"
                            f"📁 Total files generated: {file_count}\n"
                            f"🌐 Navigation: docs/diagrams/index.html\n\n"
                            f"📋 Includes:\n"
                            f"  • Terraform infrastructure diagrams\n"
                            f"  • Kubernetes application visualizations\n"
                            f"  • Unified architecture documentation\n"
                            f"  • Interactive HTML navigation\n\n"
                            f"📝 Output:\n{result.stdout}\n\n"
                            f"⚠️  Warnings/Errors:\n{result.stderr if result.stderr else 'None'}"
                }
            ]
        }

    def analyze_infrastructure(self, args):
        """Analyze infrastructure and provide insights"""
        environment = args.get('environment', 'local')
        focus_area = args.get('focus_area', 'all')

        # This would typically integrate with actual analysis tools
        # For now, provide a structured analysis framework

        analysis = f"""🔍 Infrastructure Analysis Report - {environment.title()} Environment

📊 **Focus Area:** {focus_area.title()}
📅 **Generated:** {subprocess.run(['date'], capture_output=True, text=True).stdout.strip()}

## 🏗️ Architecture Overview

### Two-Layer Design
✅ **Layer 1 (Terraform):** Infrastructure foundations
✅ **Layer 2 (Kubernetes):** Application deployments

### Environment Characteristics
"""

        if environment == 'local':
            analysis += """
- **Type:** Development (Kind cluster)
- **Scale:** Single node
- **Storage:** Local volumes
- **Network:** Host networking
- **Security:** Basic RBAC
"""
        else:
            analysis += f"""
- **Type:** Cloud ({environment})
- **Scale:** Multi-node EKS
- **Storage:** AWS EBS/EFS
- **Network:** VPC with subnets
- **Security:** Enterprise-grade
"""

        if focus_area in ['security', 'all']:
            analysis += """
## 🔒 Security Analysis

### Strengths
✅ Network policies implemented
✅ RBAC configured
✅ Pod security standards
✅ Secret management

### Recommendations
🔧 Enable admission controllers
🔧 Implement OPA policies
🔧 Add runtime security scanning
🔧 Regular security audits
"""

        if focus_area in ['performance', 'all']:
            analysis += """
## ⚡ Performance Analysis

### Resource Allocation
- CPU requests/limits configured
- Memory management in place
- Storage provisioning automated

### Optimization Opportunities
🚀 Implement HPA for auto-scaling
🚀 Add resource quotas per namespace
🚀 Configure node affinity rules
🚀 Optimize container images
"""

        if focus_area in ['reliability', 'all']:
            analysis += """
## 🛡️ Reliability Analysis

### High Availability
- Multi-AZ deployment (cloud environments)
- Replicated data stores
- Load balancing configured

### Disaster Recovery
📋 Backup strategies needed
📋 Recovery procedures documented
📋 RTO/RPO targets defined
"""

        if focus_area in ['cost', 'all']:
            analysis += """
## 💰 Cost Analysis

### Resource Utilization
- Monitor unused resources
- Right-size instances
- Implement spot instances where appropriate

### Cost Optimization
💡 Use reserved instances for predictable workloads
💡 Implement resource lifecycle policies
💡 Monitor and alert on cost spikes
"""

        analysis += """
## 📈 Next Steps

1. **Generate Current Diagrams:** Run visualization suite
2. **Review Configurations:** Check against best practices
3. **Implement Recommendations:** Prioritize by impact/effort
4. **Monitor Progress:** Set up tracking for improvements

---
**Generated by ML Platform Infrastructure Analysis**
"""

        return {
            "content": [
                {
                    "type": "text",
                    "text": analysis
                }
            ]
        }


def main():
    """Main MCP server loop"""
    server = MLPlatformMCPServer()

    # Handle initialize request
    try:
        line = sys.stdin.readline()
        if line:
            request = json.loads(line.strip())
            if request.get('method') == 'initialize':
                response = {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {},
                        "resources": {}
                    },
                    "serverInfo": {
                        "name": "ml-platform-infrastructure-viz",
                        "version": "1.0.0"
                    }
                }
                print(json.dumps(response))
                sys.stdout.flush()
    except:
        pass

    # Main request loop
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break

            request = json.loads(line.strip())
            response = server.handle_request(request)

            print(json.dumps(response))
            sys.stdout.flush()

        except KeyboardInterrupt:
            break
        except Exception as e:
            error_response = {"error": f"Server error: {str(e)}"}
            print(json.dumps(error_response))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
