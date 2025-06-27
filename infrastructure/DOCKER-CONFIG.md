# Docker Configuration Guide

The Makefile now includes an intelligent Docker socket detection and caching system that automatically resolves Docker
socket path issues across different platforms.

## 🔧 **How It Works**

### **1. Automatic Detection**

The system automatically detects and tests Docker sockets in this order:

**macOS:**

1. `~/.docker/run/docker.sock` (Docker Desktop)
2. `/var/run/docker.sock` (Standard)

**Linux:**

1. `/var/run/docker.sock` (Standard)
2. `~/.docker/run/docker.sock` (User Docker)

### **2. Connection Testing**

Each socket is tested with `docker info` to ensure it's working.

### **3. Caching**

The working socket path is cached in `infrastructure/.docker-config` for subsequent use.

## 🚀 **Usage**

### **First Time Setup**

```bash
cd infrastructure

# Detect and configure Docker socket
make docker-detect-socket
```

### **Check Docker Status**

```bash
# See current Docker configuration
make docker-status
```

### **Start Kind Cluster**

```bash
# Now works automatically with detected socket
make dev-kind-up
```

### **Force Reconfiguration**

```bash
# If Docker socket changes (e.g., Docker restart)
make docker-reconfigure
```

## 📋 **Available Commands**

| Command                | Description                        | When to Use                        |
|------------------------|------------------------------------|------------------------------------|
| `docker-detect-socket` | Detect and configure Docker socket | First time or after Docker changes |
| `docker-status`        | Show current Docker configuration  | Check if Docker is working         |
| `docker-reconfigure`   | Force socket reconfiguration       | Docker issues or socket changes    |
| `docker-get-socket`    | Get current socket (internal)      | Used by other commands             |

## 🔍 **Troubleshooting**

### **Error: No Docker socket found**

```bash
# Check if Docker is running
docker --version

# On macOS - start Docker Desktop
open -a Docker

# On Linux - start Docker service
sudo systemctl start docker
```

### **Error: Docker connection failed**

```bash
# Check Docker daemon status
docker info

# Reconfigure socket detection
make docker-reconfigure

# Check Docker Desktop settings (macOS)
# Ensure "Enable default Docker socket" is checked in Docker Desktop preferences
```

### **Error: Permission denied**

```bash
# On Linux - add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo
sudo make dev-kind-up
```

### **Socket Changed After Configuration**

```bash
# Force reconfiguration
make docker-reconfigure

# Check new status
make docker-status
```

## 🗂️ **Configuration File**

The Docker socket is cached in:

```
infrastructure/.docker-config
```

**Example content:**

```
unix:///Users/username/.docker/run/docker.sock
```

This file is:

- ✅ **Auto-generated** by socket detection
- ✅ **Git-ignored** (platform-specific)
- ✅ **Auto-validated** on each use
- ✅ **Auto-regenerated** if invalid

## 🔄 **Automatic Behavior**

### **Smart Caching**

1. **First run**: Detects and caches working socket
2. **Subsequent runs**: Uses cached socket if still working
3. **Invalid cache**: Automatically re-detects new socket
4. **No cache**: Automatically detects and creates cache

### **Integration with Commands**

All Docker-dependent commands automatically use the detection system:

- `dev-kind-up` - Uses detected socket for Terraform
- `dev-build-push` - Uses detected socket for Docker builds
- `registry-*` - Uses detected socket for local registry

## 🏗️ **Behind the Scenes**

### **Terraform Integration**

```bash
# Automatic socket detection and export
DOCKER_HOST=$(make docker-get-socket) terraform apply
```

### **Docker Commands**

```bash
# All Docker commands use detected socket
DOCKER_HOST=unix:///path/to/socket docker info
```

### **Environment Variables**

The system automatically exports `DOCKER_HOST` for Terraform's Docker provider.

## 🌍 **Platform Support**

| Platform    | Primary Socket              | Fallback Socket             | Notes                       |
|-------------|-----------------------------|-----------------------------|-----------------------------|
| **macOS**   | `~/.docker/run/docker.sock` | `/var/run/docker.sock`      | Docker Desktop default      |
| **Linux**   | `/var/run/docker.sock`      | `~/.docker/run/docker.sock` | System Docker default       |
| **Windows** | Not tested                  | Not tested                  | WSL2 should work like Linux |

## 💡 **Tips**

### **Best Practices**

1. **Run `docker-detect-socket` first** if you encounter Docker issues
2. **Check `docker-status`** before troubleshooting
3. **Use `docker-reconfigure`** after Docker Desktop restarts
4. **Don't edit `.docker-config`** manually (it will be overwritten)

### **Performance**

- Socket detection runs only when needed
- Cached socket is validated quickly
- Failed validation triggers automatic re-detection

### **CI/CD**

- Socket detection works in GitHub Actions
- Automatically handles different CI environments
- No manual configuration needed

## 🚨 **Common Issues and Solutions**

### **Issue: "Cannot connect to Docker daemon"**

**Solution:**

```bash
make docker-reconfigure
make docker-status
```

### **Issue: "Docker Desktop not running"**

**Solution:**

```bash
# Start Docker Desktop, then:
make docker-reconfigure
```

### **Issue: "Permission denied accessing socket"**

**Solution:**

```bash
# Linux: Add user to docker group
sudo usermod -aG docker $USER

# Or check socket permissions
ls -la /var/run/docker.sock
```

### **Issue: "Terraform can't find Docker provider"**

**Solution:**

```bash
# Ensure Docker socket is working
make docker-status

# If not working, reconfigure
make docker-reconfigure
```

The Docker configuration system makes Kind cluster deployment much more reliable across different platforms! 🐳
