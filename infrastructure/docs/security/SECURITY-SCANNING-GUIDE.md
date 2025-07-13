# 🔍 Security Scanning Guide

## Overview

The ML Platform includes comprehensive security scanning capabilities to identify vulnerabilities, monitor runtime security, and ensure compliance across all infrastructure components.

## 🏗️ Architecture

### Local Environment (Kubernetes)
- **Trivy Server**: Container image vulnerability scanning
- **Falco**: Runtime security monitoring and threat detection
- **Scheduled Scans**: Automated vulnerability assessments
- **Persistent Storage**: Vulnerability database caching

### Cloud Environment (AWS)
- **ECR Enhanced Scanning**: Automated container image scanning
- **AWS Inspector V2**: Infrastructure vulnerability assessment
- **GuardDuty**: Threat detection and runtime security
- **Security Hub**: Centralized security findings management
- **EventBridge**: Real-time security alert processing

## 🔧 Configuration

### Basic Configuration
```hcl
module "security_scanning" {
  source = "../../platform/security-scanning"

  name        = "ml-platform-security"
  environment = "prod"
  
  config = {
    enable_image_scanning    = true
    enable_vulnerability_db  = true
    enable_runtime_scanning  = true
    enable_compliance_check  = true
    scan_schedule           = "0 1 * * *"      # Daily at 1 AM
    severity_threshold      = "HIGH"
    enable_notifications    = true
    webhook_url            = "https://your-webhook.com/alerts"
  }
  
  namespaces = ["database", "cache", "storage", "monitoring"]
  tags = {
    Environment = "prod"
    Purpose     = "security"
  }
}
```

### Environment-Specific Settings

| Setting | Local | Dev | Staging | Prod |
|---------|-------|-----|---------|------|
| Image Scanning | ✅ | ✅ | ✅ | ✅ |
| Vulnerability DB | ✅ | ✅ | ✅ | ✅ |
| Runtime Scanning | ❌ | ✅ | ✅ | ✅ |
| Compliance Check | ❌ | ❌ | ✅ | ✅ |
| Scan Schedule | Weekly | Weekly | Daily | Daily |
| Severity Threshold | MEDIUM | MEDIUM | HIGH | HIGH |
| Notifications | ❌ | ✅ | ✅ | ✅ |

## 🚀 Getting Started

### 1. Deploy Security Scanning

```bash
# Navigate to environment
cd environments/local/

# Deploy with security scanning enabled
terraform apply -var="enable_security_scanning=true"
```

### 2. Access Security Services

#### Local Environment (Kubernetes)
```bash
# Port forward to Trivy server
kubectl port-forward -n security-scanning svc/trivy-server 4954:4954

# Port forward to Falco
kubectl port-forward -n security-scanning svc/falco 8765:8765

# Check scan job logs
kubectl logs -n security-scanning -l app.kubernetes.io/component=scanner

# Manual image scan
kubectl run -n security-scanning --rm -i --tty trivy-manual \
  --image=aquasec/trivy:0.48.3 --restart=Never -- \
  trivy image --server http://trivy-server:4954 postgres:15
```

#### AWS Environment
```bash
# View security scanning logs
aws logs describe-log-streams --log-group-name /aws/security-scanning/ml-platform

# Get ECR scan results
aws ecr describe-image-scan-findings \
  --repository-name my-app \
  --image-id imageTag=latest

# Get Inspector findings
aws inspector2 list-findings --filter-criteria '{}' --max-results 50

# Get GuardDuty findings
aws guardduty list-findings --detector-id <detector-id>

# Get Security Hub findings
aws securityhub get-findings --max-results 50
```

## 🔍 Security Scanning Features

### Container Image Scanning
- **Vulnerability Detection**: Identifies CVEs in container images
- **Dependency Analysis**: Scans application dependencies for known vulnerabilities
- **Policy Compliance**: Ensures images meet security standards
- **Continuous Monitoring**: Automated scanning on image updates

### Runtime Security Monitoring
- **Behavioral Analysis**: Monitors container runtime for suspicious activities
- **Process Monitoring**: Tracks process execution and system calls
- **Network Monitoring**: Detects unusual network connections
- **File System Monitoring**: Monitors file system changes and access patterns

### Compliance Checking
- **Security Standards**: CIS benchmarks, NIST frameworks
- **Policy Enforcement**: Custom security policies and rules
- **Configuration Assessment**: Infrastructure security configuration review
- **Compliance Reporting**: Automated compliance status reporting

## 📊 Security Dashboards and Reports

### Trivy Web UI (Local)
```bash
# Access Trivy server directly
curl http://localhost:4954/healthz

# View vulnerability database status
curl http://localhost:4954/v1/health
```

### Falco Alerts (Local)
```bash
# View Falco alerts in real-time
kubectl logs -n security-scanning -f deployment/falco

# Access Falco web interface
kubectl port-forward -n security-scanning svc/falco 8765:8765
# Then visit: http://localhost:8765
```

### AWS Security Hub (Cloud)
- Centralized security findings dashboard
- Cross-service vulnerability correlation
- Automated remediation recommendations
- Compliance posture monitoring

## 🚨 Alert Configuration

### Severity Levels
- **CRITICAL**: Immediate action required
- **HIGH**: Address within 24 hours
- **MEDIUM**: Address within 1 week
- **LOW**: Address during maintenance windows

### Notification Channels
- **Webhook**: HTTP POST to custom endpoints
- **AWS SNS**: Email, SMS, or application notifications
- **CloudWatch Logs**: Centralized log aggregation
- **Security Hub**: AWS native security notifications

### Custom Alert Rules
```yaml
# Example Falco rule for detecting sensitive file access
- rule: Sensitive File Access
  desc: Detect access to sensitive files
  condition: >
    open_read and
    fd.name in (/etc/passwd, /etc/shadow, /etc/sudoers)
  output: >
    Sensitive file accessed (user=%user.name command=%proc.cmdline file=%fd.name)
  priority: HIGH
  tags: [filesystem, security]
```

## 🔧 Troubleshooting

### Common Issues

#### Trivy Server Not Starting
```bash
# Check pod status
kubectl get pods -n security-scanning

# Check logs
kubectl logs -n security-scanning deployment/trivy-server

# Common fix: Increase resource limits
```

#### Database Update Failures
```bash
# Manually update vulnerability database
kubectl exec -n security-scanning deployment/trivy-server -- \
  trivy image --download-db-only

# Check storage space
kubectl describe pvc -n security-scanning trivy-cache
```

#### False Positive Alerts
```bash
# Update Falco rules to reduce noise
kubectl edit configmap -n security-scanning falco-config

# Adjust severity thresholds in Terraform configuration
```

### Performance Tuning

#### Scan Optimization
```hcl
config = {
  scan_schedule = "0 2 * * 0"  # Weekly instead of daily
  severity_threshold = "HIGH"  # Focus on high-severity issues
}
```

#### Resource Allocation
```hcl
# Kubernetes resources
resources {
  limits = {
    cpu    = "1000m"
    memory = "2Gi"
  }
  requests = {
    cpu    = "500m"
    memory = "1Gi"
  }
}
```

## 📈 Security Metrics

### Key Performance Indicators
- **Mean Time to Detection (MTTD)**: Average time to identify threats
- **Mean Time to Response (MTTR)**: Average time to respond to incidents
- **Vulnerability Coverage**: Percentage of infrastructure scanned
- **False Positive Rate**: Ratio of false alerts to total alerts

### Monitoring Queries
```bash
# Count high-severity vulnerabilities
aws logs filter-log-events \
  --log-group-name /aws/security-scanning/ml-platform \
  --filter-pattern '{ $.severity = "HIGH" }'

# Runtime security events in last 24 hours
kubectl logs -n security-scanning --since=24h -l app.kubernetes.io/name=falco | grep CRITICAL
```

## 🛡️ Security Best Practices

### Container Security
1. **Base Image Security**: Use minimal, regularly updated base images
2. **Multi-stage Builds**: Reduce attack surface in final images
3. **Non-root Users**: Run containers with non-privileged users
4. **Read-only Filesystems**: Mount container filesystems as read-only

### Infrastructure Security
1. **Network Segmentation**: Implement micro-segmentation with network policies
2. **Least Privilege**: Grant minimum required permissions
3. **Regular Updates**: Keep all components updated with latest patches
4. **Backup Security**: Encrypt and regularly test backup recovery

### Monitoring Security
1. **Log Retention**: Maintain logs for compliance and forensic analysis
2. **Alert Tuning**: Balance between alert fatigue and coverage
3. **Incident Response**: Maintain documented response procedures
4. **Regular Testing**: Conduct security drills and penetration testing

## 🔄 Integration with CI/CD

### Pre-deployment Scanning
```yaml
# GitHub Actions integration
- name: Container Security Scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'my-app:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

### Automated Remediation
- **Vulnerability Patching**: Automated dependency updates
- **Image Rebuilding**: Trigger rebuilds on vulnerability discoveries
- **Policy Enforcement**: Block deployments failing security thresholds
- **Compliance Reporting**: Automated compliance status updates

## 📚 Additional Resources

- [Trivy Documentation](https://trivy.dev/)
- [Falco Documentation](https://falco.org/)
- [AWS Inspector User Guide](https://docs.aws.amazon.com/inspector/)
- [AWS GuardDuty User Guide](https://docs.aws.amazon.com/guardduty/)
- [AWS Security Hub User Guide](https://docs.aws.amazon.com/securityhub/)

## 🎯 Next Steps

1. **Configure Alerting**: Set up notification channels for your team
2. **Tune Policies**: Adjust security policies based on your requirements
3. **Integrate SIEM**: Connect security scanning to your SIEM solution
4. **Schedule Reviews**: Regular security posture assessments
5. **Train Team**: Security awareness and incident response training