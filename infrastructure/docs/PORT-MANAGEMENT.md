# Port Management Solution for ML Platform

## Problem Solved

As services grow in the ML platform, port management becomes challenging with:
- **Port conflicts** between services (Grafana and Frontend both using 3000)
- **Scattered port definitions** across multiple files  
- **No centralized registry** for port allocation
- **Risk of duplicates** when adding new services

## Solution Overview

### ✅ Centralized Port Registry
**File**: `/infrastructure/shared/config/ports.yaml`
- Single source of truth for all port assignments
- Organized by service type with standardized ranges
- Environment-specific overrides supported
- Conflict detection and resolution tracking

### ✅ Automated Port Management
**File**: `/infrastructure/shared/makefiles/ports.mk`
- Dynamic port assignment using variables
- Environment-aware port resolution
- Port validation and conflict checking
- Automated docker-compose port updates

### ✅ Port Validation Script
**File**: `/infrastructure/shared/scripts/validate-ports.sh`
- Detects duplicate port assignments
- Checks for reserved/well-known port conflicts
- Validates port ranges and environment overrides
- Generates comprehensive port usage reports

## Port Range Standards

| Range | Purpose | Examples |
|-------|---------|----------|
| 80-443 | External access | HTTP, HTTPS, Kubernetes API |
| 3000-3999 | Frontend/UI | React app (3000), Admin dashboard (3001) |
| 5000-5999 | Data storage | PostgreSQL (5432), Registry (5000) |
| 6000-6999 | Message queues | Kafka (9092), Redis (6379) |
| 8000-8999 | API services | Backend (8000), ML API (8001), Auth (8002) |
| 9000-9999 | Monitoring | Prometheus (9090), Grafana (9091), MinIO (9000) |

## Key Conflicts Resolved

### 1. Grafana Port Conflict
- **Before**: Grafana (3000) vs Frontend (3000) ❌
- **After**: Grafana moved to 9091, Frontend keeps 3000 ✅

### 2. Multiple Services on Port 8000
- **Before**: Backend API, Kubernetes Dashboard, Kong all using 8000 ❌  
- **After**: Dashboard moved to 8300-8399 range, Kong to 8100+ ✅

### 3. Registry Port Management
- **Before**: Hardcoded `localhost:25000` ❌
- **After**: Variable `$(REGISTRY_EXTERNAL_PORT)` ✅

## Usage Examples

### View Current Port Assignments
```bash
cd infrastructure/kind/sandbox
make show-ports
```

### Validate Port Configuration
```bash
make validate-ports
```

### Generate Port Environment File
```bash
make generate-port-env
```

### Check Port Conflicts
```bash
make list-port-conflicts
```

### Reserve New Port Range
```bash
make reserve-port-range START_PORT=10000 END_PORT=10099 PURPOSE="New ML services"
```

## Environment-Specific Configuration

### Kind Development
- Uses host port mappings for external access
- Registry accessible at `localhost:25000`
- All services use standard internal ports

### Docker Compose Development  
- Environment overrides for external ports
- Services accessible directly from host
- Port conflicts resolved automatically

### AWS/Cloud Production
- Uses ClusterIP services (no host ports)
- External access via Load Balancers
- Internal service discovery by name

## Benefits Achieved

### ✅ Scalability
- Easy to add new services without conflicts
- Standardized port ranges prevent overlap
- Reserved ranges for future expansion

### ✅ Maintainability  
- Single place to manage all ports
- Consistent port assignment across environments
- Automated validation prevents deployment issues

### ✅ Developer Experience
- Clear port assignments visible in one place
- Environment-specific port resolution
- Automated conflict detection and resolution

## Files Modified

### Configuration Files
- `infrastructure/shared/config/ports.yaml` - **NEW** centralized registry
- `infrastructure/shared/makefiles/ports.mk` - **NEW** port management
- `infrastructure/shared/makefiles/common.mk` - includes port management

### Fixed Conflicts
- `infrastructure/shared/kubernetes/base/network/monitoring-ingress.yaml` - Grafana 3000→9091
- `infrastructure/kubernetes/base/network/monitoring-ingress.yaml` - Grafana 3000→9091  
- `infrastructure/kind/sandbox/docker-compose.yml` - Variable port mappings
- `infrastructure/kind/sandbox/Makefile` - Variable registry ports

### Validation Tools
- `infrastructure/shared/scripts/validate-ports.sh` - **NEW** validation script
- `docs/port-management.md` - **NEW** documentation

## Adding New Services

When adding a new service:

1. **Check port registry** for available ports in the appropriate range
2. **Add to ports.yaml** in the correct service category  
3. **Run validation** to ensure no conflicts
4. **Update service configs** to use port variables
5. **Test across environments** to verify functionality

## Future Enhancements

- **GitOps Integration**: Automated port validation in CI/CD pipelines
- **Service Mesh**: Abstract port management with service discovery  
- **Monitoring Integration**: Port usage metrics and alerting
- **Documentation Generation**: Auto-generate port documentation from registry