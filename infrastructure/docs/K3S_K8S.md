<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>K3s vs K8s Comparison</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        
        h1 {
            text-align: center;
            color: #2c3e50;
            margin-bottom: 40px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
        }
        
        .architecture-section {
            margin-bottom: 50px;
        }
        
        .architecture-title {
            font-size: 1.8em;
            color: #34495e;
            margin-bottom: 20px;
            text-align: center;
            padding: 15px;
            background: linear-gradient(90deg, #3498db, #2980b9);
            color: white;
            border-radius: 10px;
        }
        
        .diagrams-container {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 40px;
        }
        
        .diagram {
            background: white;
            border-radius: 15px;
            padding: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            border: 2px solid #e8f4f8;
        }
        
        .diagram h3 {
            text-align: center;
            margin-bottom: 20px;
            color: #2c3e50;
            font-size: 1.3em;
        }
        
        .node {
            background: #ecf0f1;
            border: 2px solid #bdc3c7;
            border-radius: 10px;
            padding: 15px;
            margin: 10px 0;
            position: relative;
        }
        
        .control-plane {
            background: linear-gradient(135deg, #ff6b6b, #ee5a52);
            color: white;
            border-color: #c0392b;
        }
        
        .worker-node {
            background: linear-gradient(135deg, #4ecdc4, #44a08d);
            color: white;
            border-color: #16a085;
        }
        
        .k3s-node {
            background: linear-gradient(135deg, #f39c12, #e67e22);
            color: white;
            border-color: #d35400;
        }
        
        .component {
            background: rgba(255, 255, 255, 0.2);
            border-radius: 5px;
            padding: 8px;
            margin: 5px 0;
            font-size: 0.9em;
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        
        .table-container {
            overflow-x: auto;
            margin: 20px 0;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 15px;
            overflow: hidden;
        }
        
        th {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 20px;
            text-align: left;
            font-weight: 600;
            font-size: 1.1em;
        }
        
        td {
            padding: 15px 20px;
            border-bottom: 1px solid #ecf0f1;
            vertical-align: top;
        }
        
        tr:hover {
            background: #f8f9fa;
            transform: scale(1.01);
            transition: all 0.3s ease;
        }
        
        .pro {
            color: #27ae60;
            font-weight: bold;
        }
        
        .con {
            color: #e74c3c;
            font-weight: bold;
        }
        
        .highlight {
            background: linear-gradient(135deg, #74b9ff, #0984e3);
            color: white;
            padding: 2px 8px;
            border-radius: 5px;
            font-weight: bold;
        }
        
        .section-divider {
            height: 3px;
            background: linear-gradient(90deg, #667eea, #764ba2);
            border: none;
            border-radius: 2px;
            margin: 40px 0;
        }
        
        @media (max-width: 768px) {
            .diagrams-container {
                grid-template-columns: 1fr;
            }
            
            .container {
                padding: 20px;
            }
            
            h1 {
                font-size: 2em;
            }
        }
    </style>

</head>
<body>
    <div class="container">
        <h1>🚀 K3s vs K8s Architecture Comparison</h1>

        <div class="architecture-section">
            <div class="architecture-title">📐 Architecture Diagrams</div>
            
            <div class="diagrams-container">
                <div class="diagram">
                    <h3>🏗️ Standard Kubernetes (K8s)</h3>
                    <div class="node control-plane">
                        <strong>Control Plane Node(s)</strong>
                        <div class="component">📡 kube-apiserver</div>
                        <div class="component">🗄️ etcd</div>
                        <div class="component">📅 kube-scheduler</div>
                        <div class="component">🎮 kube-controller-manager</div>
                        <div class="component">☁️ cloud-controller-manager</div>
                    </div>
                    
                    <div class="node worker-node">
                        <strong>Worker Node 1</strong>
                        <div class="component">🔧 kubelet</div>
                        <div class="component">🌐 kube-proxy</div>
                        <div class="component">📦 Container Runtime</div>
                        <div class="component">🚀 Application Pods</div>
                    </div>
                    
                    <div class="node worker-node">
                        <strong>Worker Node 2</strong>
                        <div class="component">🔧 kubelet</div>
                        <div class="component">🌐 kube-proxy</div>
                        <div class="component">📦 Container Runtime</div>
                        <div class="component">🚀 Application Pods</div>
                    </div>
                </div>
                
                <div class="diagram">
                    <h3>🎯 K3s (Lightweight Kubernetes)</h3>
                    <div class="node k3s-node">
                        <strong>K3s Server (All-in-One)</strong>
                        <div class="component">📡 kube-apiserver</div>
                        <div class="component">🗃️ SQLite/etcd</div>
                        <div class="component">📅 kube-scheduler</div>
                        <div class="component">🎮 kube-controller-manager</div>
                        <div class="component">🔧 kubelet</div>
                        <div class="component">🌐 kube-proxy</div>
                        <div class="component">📦 containerd</div>
                        <div class="component">🚀 Application Pods</div>
                    </div>
                    
                    <div class="node k3s-node" style="opacity: 0.7;">
                        <strong>K3s Agent (Optional)</strong>
                        <div class="component">🔧 kubelet</div>
                        <div class="component">🌐 kube-proxy</div>
                        <div class="component">📦 containerd</div>
                        <div class="component">🚀 Application Pods</div>
                    </div>
                </div>
            </div>
        </div>
        
        <hr class="section-divider">
        
        <div class="architecture-section">
            <div class="architecture-title">⚖️ Detailed Comparison</div>
            
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Aspect</th>
                            <th>K8s (Standard)</th>
                            <th>K3s (Lightweight)</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>🎯 Purpose</strong></td>
                            <td>Production-grade, full-featured orchestration</td>
                            <td>Lightweight, edge computing, IoT, development</td>
                        </tr>
                        <tr>
                            <td><strong>💾 Binary Size</strong></td>
                            <td>~100MB+ (multiple components)</td>
                            <td><span class="highlight">~60MB</span> (single binary)</td>
                        </tr>
                        <tr>
                            <td><strong>🧠 Memory Usage</strong></td>
                            <td>~1-2GB minimum</td>
                            <td><span class="highlight">~512MB</span> minimum</td>
                        </tr>
                        <tr>
                            <td><strong>🗄️ Datastore</strong></td>
                            <td>etcd (distributed)</td>
                            <td><span class="highlight">SQLite</span> (default) or etcd</td>
                        </tr>
                        <tr>
                            <td><strong>📦 Container Runtime</strong></td>
                            <td>Docker, containerd, CRI-O</td>
                            <td><span class="highlight">containerd</span> (built-in)</td>
                        </tr>
                        <tr>
                            <td><strong>🔧 Installation</strong></td>
                            <td>Complex (kubeadm, kops, etc.)</td>
                            <td><span class="highlight">Single script</span> installation</td>
                        </tr>
                        <tr>
                            <td><strong>🏗️ Architecture</strong></td>
                            <td>Separate control plane + worker nodes</td>
                            <td><span class="highlight">All-in-one</span> or distributed</td>
                        </tr>
                        <tr>
                            <td><strong>🌐 Networking</strong></td>
                            <td>Requires CNI plugin selection</td>
                            <td><span class="highlight">Flannel</span> included by default</td>
                        </tr>
                        <tr>
                            <td><strong>📊 Monitoring</strong></td>
                            <td>Requires separate setup</td>
                            <td>Basic metrics included</td>
                        </tr>
                        <tr>
                            <td><strong>🔐 Security</strong></td>
                            <td>Full RBAC, network policies</td>
                            <td>Simplified security model</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        
        <hr class="section-divider">
        
        <div class="architecture-section">
            <div class="architecture-title">✅ Pros & Cons</div>
            
            <div class="diagrams-container">
                <div class="diagram">
                    <h3>🏗️ Standard Kubernetes</h3>
                    <div style="margin-bottom: 20px;">
                        <h4 class="pro">✅ Pros:</h4>
                        <ul>
                            <li>Production-ready and battle-tested</li>
                            <li>Full feature set and ecosystem</li>
                            <li>High availability and scalability</li>
                            <li>Extensive community support</li>
                            <li>Fine-grained control and configuration</li>
                        </ul>
                    </div>
                    <div>
                        <h4 class="con">❌ Cons:</h4>
                        <ul>
                            <li>Complex setup and maintenance</li>
                            <li>High resource requirements</li>
                            <li>Steep learning curve</li>
                            <li>Overkill for simple deployments</li>
                        </ul>
                    </div>
                </div>
                
                <div class="diagram">
                    <h3>🎯 K3s</h3>
                    <div style="margin-bottom: 20px;">
                        <h4 class="pro">✅ Pros:</h4>
                        <ul>
                            <li>Lightweight and fast</li>
                            <li>Simple installation and management</li>
                            <li>Perfect for edge computing</li>
                            <li>Low resource footprint</li>
                            <li>Great for development/testing</li>
                        </ul>
                    </div>
                    <div>
                        <h4 class="con">❌ Cons:</h4>
                        <ul>
                            <li>Limited customization options</li>
                            <li>Less suitable for large clusters</li>
                            <li>Fewer enterprise features</li>
                            <li>SQLite limitations for HA</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
        
        <hr class="section-divider">
        
        <div class="architecture-section">
            <div class="architecture-title">🎯 Use Cases</div>
            
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Scenario</th>
                            <th>Recommended Choice</th>
                            <th>Reason</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>🏭 Production Enterprise</strong></td>
                            <td><span class="highlight">K8s</span></td>
                            <td>Full features, HA, security, scalability</td>
                        </tr>
                        <tr>
                            <td><strong>🖥️ Development/Testing</strong></td>
                            <td><span class="highlight">K3s</span></td>
                            <td>Quick setup, low resources, easy reset</td>
                        </tr>
                        <tr>
                            <td><strong>🌐 Edge Computing</strong></td>
                            <td><span class="highlight">K3s</span></td>
                            <td>Lightweight, single-node capable</td>
                        </tr>
                        <tr>
                            <td><strong>🏠 Home Lab</strong></td>
                            <td><span class="highlight">K3s</span></td>
                            <td>Raspberry Pi friendly, low power</td>
                        </tr>
                        <tr>
                            <td><strong>📱 IoT Devices</strong></td>
                            <td><span class="highlight">K3s</span></td>
                            <td>Minimal footprint, ARM support</td>
                        </tr>
                        <tr>
                            <td><strong>🎓 Learning Kubernetes</strong></td>
                            <td><span class="highlight">K3s</span></td>
                            <td>Easy to get started, less complexity</td>
                        </tr>
                        <tr>
                            <td><strong>💼 Multi-cloud Production</strong></td>
                            <td><span class="highlight">K8s</span></td>
                            <td>Vendor flexibility, enterprise features</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

</body>
</html>
