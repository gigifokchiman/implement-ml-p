# Operational Runbooks

This document provides step-by-step procedures for common operational tasks.

## Table of Contents
- [Emergency Procedures](#emergency-procedures)
- [Deployment Procedures](#deployment-procedures)
- [Backup and Recovery](#backup-and-recovery)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Troubleshooting](#troubleshooting)
- [Security Incidents](#security-incidents)

## Emergency Procedures

### 🚨 Complete Infrastructure Outage

**Immediate Actions (0-5 minutes):**
1. Check status page: `kubectl get nodes` (local) or AWS Console (cloud)
2. Verify network connectivity: `ping <endpoint>`
3. Check recent deployments: `git log --oneline -10`
4. Alert stakeholders via Slack/Teams

**Assessment (5-15 minutes):**
1. Check infrastructure status:
   ```bash
   # Local environment
   kubectl get pods --all-namespaces
   kubectl get services --all-namespaces
   
   # Cloud environment
   terraform output -json | jq '.'
   aws eks describe-cluster --name <cluster-name>
   ```

2. Check monitoring dashboards:
   - Grafana: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
   - Prometheus: `kubectl port-forward -n monitoring svc/prometheus-server 9090:9090`

**Recovery (15+ minutes):**
1. If infrastructure is down:
   ```bash
   cd environments/<environment>
   terraform plan
   terraform apply
   ```

2. If application is down:
   ```bash
   kubectl rollout restart deployment/<deployment-name> -n <namespace>
   ```

### 🔥 Database Outage

**Immediate Actions:**
1. Check database status:
   ```bash
   # Local
   kubectl get pods -n database
   kubectl logs -n database deployment/postgres --tail=50
   
   # Cloud
   aws rds describe-db-instances --db-instance-identifier <instance-id>
   ```

2. Check connections:
   ```bash
   kubectl port-forward -n database svc/postgres 5432:5432
   psql -h localhost -U admin -d metadata
   ```

**Recovery:**
1. Restart database:
   ```bash
   # Local
   kubectl rollout restart deployment/postgres -n database
   
   # Cloud
   aws rds reboot-db-instance --db-instance-identifier <instance-id>
   ```

2. Restore from backup if needed:
   ```bash
   # Local (Velero)
   velero restore create --from-backup database-backup-<timestamp>
   
   # Cloud (AWS Backup)
   aws rds restore-db-instance-from-db-snapshot --db-instance-identifier <new-id> --db-snapshot-identifier <snapshot-id>
   ```

## Deployment Procedures

### 🚀 Standard Deployment

**Pre-deployment Checklist:**
- [ ] Code reviewed and approved
- [ ] Tests passing
- [ ] Staging deployment successful
- [ ] Backup created
- [ ] Rollback plan documented

**Deployment Steps:**
1. **Local Environment:**
   ```bash
   cd environments/local
   terraform plan -var-file="terraform.tfvars"
   terraform apply -var-file="terraform.tfvars"
   ```

2. **Development Environment:**
   ```bash
   cd environments/dev
   terraform plan -var-file="terraform.tfvars"
   terraform apply -var-file="terraform.tfvars"
   ```

3. **Staging Environment:**
   ```bash
   cd environments/staging
   terraform plan -var-file="terraform.tfvars"
   terraform apply -var-file="terraform.tfvars"
   ```

4. **Production Environment:**
   ```bash
   cd environments/prod
   terraform plan -var-file="terraform.tfvars"
   # Get approval from team leads
   terraform apply -var-file="terraform.tfvars"
   ```

**Post-deployment Verification:**
```bash
# Check all services
kubectl get pods --all-namespaces
kubectl get services --all-namespaces

# Verify database connectivity
terraform output service_connections

# Check monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### 🔄 Rollback Procedure

**Immediate Rollback:**
```bash
# Revert to previous Terraform state
terraform state pull > current-state.json
terraform state push previous-state.json
terraform apply

# Or revert specific resources
kubectl rollout undo deployment/<deployment-name> -n <namespace>
```

**Database Rollback:**
```bash
# Local (from Velero backup)
velero restore create --from-backup database-backup-<previous-timestamp>

# Cloud (from RDS snapshot)
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier <id> --db-snapshot-identifier <snapshot-id>
```

## Backup and Recovery

### 📦 Manual Backup Creation

**Local Environment (Velero):**
```bash
# Create full backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) --include-namespaces database,cache,storage

# Create namespace-specific backup
velero backup create database-backup-$(date +%Y%m%d-%H%M%S) --include-namespaces database

# List backups
velero backup get
```

**Cloud Environment (AWS Backup):**
```bash
# Create RDS snapshot
aws rds create-db-snapshot --db-instance-identifier <instance-id> --db-snapshot-identifier manual-snapshot-$(date +%Y%m%d-%H%M%S)

# Create S3 backup
aws s3 sync s3://<source-bucket> s3://<backup-bucket> --delete
```

### 🔄 Recovery Procedures

**Full Environment Recovery:**
```bash
# 1. Recreate infrastructure
cd environments/<environment>
terraform destroy  # Only if necessary
terraform apply

# 2. Restore data
# Local
velero restore create --from-backup <backup-name>

# Cloud
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier <new-id> --db-snapshot-identifier <snapshot-id>
```

**Partial Recovery (Database Only):**
```bash
# Local
kubectl delete namespace database
velero restore create database-recovery --from-backup <backup-name> --include-namespaces database

# Cloud
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier <id> --db-snapshot-identifier <snapshot-id>
```

## Monitoring and Alerting

### 📊 Access Monitoring Dashboards

**Grafana:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access: http://localhost:3000 (admin/admin123)
```

**Prometheus:**
```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Access: http://localhost:9090
```

**AlertManager:**
```bash
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
# Access: http://localhost:9093
```

### 🔔 Alert Investigation

**Database Alerts:**
```bash
# Check database status
kubectl get pods -n database
kubectl logs -n database deployment/postgres --tail=100

# Check connections
kubectl exec -n database deployment/postgres -- psql -U admin -d metadata -c "SELECT version();"

# Check resource usage
kubectl top pods -n database
```

**Storage Alerts:**
```bash
# Check MinIO status
kubectl get pods -n storage
kubectl logs -n storage deployment/minio --tail=100

# Check storage usage
kubectl exec -n storage deployment/minio -- df -h /data
```

## Troubleshooting

### 🔍 Common Issues

**Pod Stuck in Pending:**
```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check PVC status
kubectl get pvc -n <namespace>
```

**Service Not Accessible:**
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Check network policies
kubectl get networkpolicies -n <namespace>

# Test connectivity
kubectl run debug --image=busybox -it --rm -- wget -qO- <service-url>
```

**Performance Issues:**
```bash
# Check resource usage
kubectl top pods --all-namespaces
kubectl top nodes

# Check metrics in Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### 🐛 Debug Commands

**General Debugging:**
```bash
# Get all resources in namespace
kubectl get all -n <namespace>

# Describe problematic resource
kubectl describe <resource-type> <resource-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace> --tail=100 -f

# Execute into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

**Network Debugging:**
```bash
# Test DNS resolution
kubectl run debug --image=busybox -it --rm -- nslookup <service-name>.<namespace>.svc.cluster.local

# Test service connectivity
kubectl run debug --image=busybox -it --rm -- telnet <service-name>.<namespace>.svc.cluster.local <port>

# Check network policies
kubectl get networkpolicies --all-namespaces
```

## Security Incidents

### 🛡️ Security Incident Response

**Immediate Actions:**
1. **Isolate affected systems:**
   ```bash
   # Block network access
   kubectl apply -f - <<EOF
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: deny-all-emergency
     namespace: <affected-namespace>
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
     - Egress
   EOF
   ```

2. **Preserve evidence:**
   ```bash
   # Export logs
   kubectl logs <pod-name> -n <namespace> > incident-logs-$(date +%Y%m%d-%H%M%S).txt
   
   # Export configurations
   kubectl get all -n <namespace> -o yaml > incident-config-$(date +%Y%m%d-%H%M%S).yaml
   ```

3. **Assess damage:**
   ```bash
   # Check for unauthorized changes
   kubectl get events --sort-by=.metadata.creationTimestamp
   
   # Review access logs
   kubectl logs -n kube-system -l component=kube-apiserver
   ```

**Recovery Actions:**
1. **Patch vulnerabilities:**
   ```bash
   # Update container images
   kubectl set image deployment/<deployment> <container>=<new-image> -n <namespace>
   
   # Apply security updates
   terraform apply
   ```

2. **Restore from clean backup:**
   ```bash
   velero restore create security-recovery --from-backup <clean-backup-name>
   ```

3. **Update security policies:**
   ```bash
   # Apply stricter network policies
   kubectl apply -f enhanced-security-policies.yaml
   
   # Update RBAC
   kubectl apply -f rbac-policies.yaml
   ```

### 📋 Incident Documentation Template

```markdown
# Security Incident Report

**Date:** 
**Severity:** 
**Affected Systems:** 
**Reporter:** 

## Summary

## Timeline

## Impact Assessment

## Root Cause Analysis

## Actions Taken

## Lessons Learned

## Follow-up Actions
```

---

## Contact Information

- **On-call Engineer:** Slack @oncall
- **Security Team:** security@company.com
- **Infrastructure Team:** infra@company.com
- **Emergency Escalation:** +1-XXX-XXX-XXXX

## Additional Resources

- [Monitoring Dashboards](docs/MONITORING.md)
- [Security Policies](docs/SECURITY.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)