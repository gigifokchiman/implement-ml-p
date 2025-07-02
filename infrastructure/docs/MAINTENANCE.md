# Infrastructure Maintenance Guide

This guide outlines regular maintenance tasks for the ML Platform infrastructure.

## Daily Maintenance

### Automated Checks

- [ ] Terraform drift detection (via CI/CD)
- [ ] Security scanning (Checkov, tfsec)
- [ ] Container vulnerability scanning
- [ ] Cost monitoring alerts

### Manual Checks (if needed)

- [ ] Check resource utilization
- [ ] Review application logs
- [ ] Monitor backup status

## Weekly Maintenance

### Infrastructure Review

- [ ] Review Terraform state for drift
- [ ] Check for unused resources
- [ ] Review security scan reports
- [ ] Update container images

### Performance Review

- [ ] Review monitoring dashboards
- [ ] Check resource quotas
- [ ] Analyze cost reports
- [ ] Review scaling events

### Commands

```bash
# Check infrastructure status
make status

# Run security scans
make docker-security-scan

# Update container images
docker pull ml-platform/infra-tools:latest
make docker-build
```

## Monthly Maintenance

### Version Updates

- [ ] Review Terraform provider updates
- [ ] Check for Helm chart updates
- [ ] Update base Docker images
- [ ] Review Kubernetes version compatibility

### Security Review

- [ ] Rotate access keys and certificates
- [ ] Review IAM permissions
- [ ] Update security policies
- [ ] Review network policies

### Backup Testing

- [ ] Test backup restoration procedures
- [ ] Verify backup retention policies
- [ ] Check cross-region backup replication

### Commands

```bash
# Update Terraform providers
cd terraform/environments/local && terraform init -upgrade

# Update Helm charts
helm repo update

# Check for outdated images
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}"
```

## Quarterly Maintenance

### Architecture Review

- [ ] Review infrastructure architecture
- [ ] Assess scaling requirements
- [ ] Plan capacity upgrades
- [ ] Review disaster recovery procedures

### Cost Optimization

- [ ] Right-size resources
- [ ] Review storage utilization
- [ ] Optimize data retention policies
- [ ] Evaluate reserved instances

### Documentation Updates

- [ ] Update architecture diagrams
- [ ] Review and update runbooks
- [ ] Update deployment procedures
- [ ] Refresh troubleshooting guides

## Annual Maintenance

### Major Version Updates

- [ ] Plan Kubernetes cluster upgrades
- [ ] Terraform major version updates
- [ ] Database engine upgrades
- [ ] SSL certificate renewals

### Security Audit

- [ ] Comprehensive security audit
- [ ] Penetration testing
- [ ] Access control review
- [ ] Compliance assessment

### Disaster Recovery Testing

- [ ] Full disaster recovery drill
- [ ] Cross-region failover testing
- [ ] Backup restoration testing
- [ ] Business continuity validation

## Maintenance Commands

### Regular Cleanup

```bash
# Clean temporary files and artifacts
make deep-clean

# Clean Docker resources
make docker-clean

# Format and validate code
make format validate
```

### Health Checks

```bash
# Check infrastructure health
make docker-health

# Validate Terraform configurations
make validate

# Run infrastructure tests
make test
```

### Monitoring

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check storage usage
kubectl get pv
kubectl get pvc --all-namespaces

# Check service status
kubectl get services --all-namespaces
```

## Maintenance Schedule

### Recommended Schedule

| Task                | Frequency | Preferred Time             | Duration |
|---------------------|-----------|----------------------------|----------|
| Security scans      | Daily     | Automated                  | 15 min   |
| Resource review     | Weekly    | Monday 9 AM                | 30 min   |
| Version updates     | Monthly   | First Friday               | 2 hours  |
| Architecture review | Quarterly | End of quarter             | 4 hours  |
| DR testing          | Annually  | Planned maintenance window | 8 hours  |

### Maintenance Windows

| Environment | Window          | Duration | Frequency |
|-------------|-----------------|----------|-----------|
| Local       | Anytime         | N/A      | As needed |
| Dev         | Weekdays 6-8 AM | 2 hours  | Weekly    |
| Staging     | Weekends 2-4 AM | 2 hours  | Monthly   |
| Production  | Sundays 2-6 AM  | 4 hours  | Quarterly |

## Emergency Maintenance

### Critical Issues

- [ ] Security vulnerabilities (CVE)
- [ ] Data breaches
- [ ] System outages
- [ ] Performance degradation

### Emergency Response

1. **Assess Impact**: Determine scope and severity
2. **Notify Stakeholders**: Alert relevant teams
3. **Implement Fix**: Apply emergency patches
4. **Monitor**: Watch for stability
5. **Document**: Record incident and resolution

### Emergency Contacts

- Infrastructure Team: `infra-team@company.com`
- Security Team: `security@company.com`
- On-call Engineer: Check incident management system

## Maintenance Logs

### Log Template

```
Date: YYYY-MM-DD
Maintainer: Name
Task: Description
Environment: local/dev/staging/prod
Duration: X hours
Issues: Any problems encountered
Next Actions: Follow-up tasks
```

### Log Location

- Maintenance logs: `docs/maintenance-logs/`
- Incident reports: `docs/incidents/`
- Change requests: Issue tracking system

## Automation

### Automated Tasks

- Daily security scans
- Weekly resource reports
- Monthly vulnerability updates
- Backup verification

### CI/CD Integration

```yaml
# .github/workflows/maintenance.yml
name: Infrastructure Maintenance
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2 AM
jobs:
  maintenance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run maintenance
        run: make deep-clean validate test
```

## Troubleshooting

### Common Issues

1. **Terraform State Lock**: `terraform force-unlock <lock_id>`
2. **Docker Image Issues**: `make docker-clean && make docker-build`
3. **Permission Issues**: Check IAM roles and RBAC
4. **Resource Limits**: Review quotas and limits

### Debugging Commands

```bash
# Check Terraform state
terraform show

# Debug Kubernetes issues
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Check infrastructure health
make docker-health
./scripts/cleanup-infrastructure.sh
```

## Best Practices

### Before Maintenance

- [ ] Review change requirements
- [ ] Check maintenance windows
- [ ] Backup critical data
- [ ] Notify stakeholders
- [ ] Prepare rollback plan

### During Maintenance

- [ ] Follow documented procedures
- [ ] Monitor system health
- [ ] Log all changes
- [ ] Test functionality
- [ ] Verify monitoring

### After Maintenance

- [ ] Confirm system stability
- [ ] Update documentation
- [ ] Notify completion
- [ ] Schedule follow-up checks
- [ ] Review lessons learned

## Resource Links

- [Infrastructure Documentation](../README.md)
- [Docker Setup Guide](archive/DOCKER-SETUP.md)
- [Troubleshooting Guide](../tests/TROUBLESHOOTING.md)
- [Security Guidelines](./SECURITY.md)
- [Architecture Overview](./ARCHITECTURE.md)
