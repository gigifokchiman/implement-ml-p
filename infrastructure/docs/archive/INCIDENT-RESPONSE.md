# Incident Response Runbook

## Overview

This runbook provides step-by-step procedures for responding to production incidents and disasters affecting the ML Platform infrastructure.

## Incident Severity Classification

### Critical (P0)
- Complete service outage
- Data loss or corruption
- Security breach
- Revenue-impacting issues

**Response Time:** 15 minutes
**Escalation:** Immediate to on-call engineer and manager

### High (P1)
- Partial service outage
- Performance degradation >50%
- Key feature unavailable
- Customer-facing errors

**Response Time:** 30 minutes
**Escalation:** To on-call engineer

### Medium (P2)
- Minor feature issues
- Performance degradation <50%
- Non-customer-facing errors

**Response Time:** 2 hours
**Escalation:** During business hours

### Low (P3)
- Cosmetic issues
- Documentation problems
- Non-urgent improvements

**Response Time:** 24 hours
**Escalation:** During business hours

## Incident Response Process

### 1. Incident Detection and Alerting

#### Automated Detection
- Monitor alerting systems (Prometheus, Grafana, PagerDuty)
- Synthetic monitoring (Pingdom, BlackBox exporter)
- Application health checks
- Infrastructure monitoring (CloudWatch, DataDog)

#### Manual Reporting
- Customer reports
- Internal team reports
- Partner notifications

#### Initial Assessment
```bash
# Quick health check commands
kubectl get pods --all-namespaces | grep -v Running
kubectl get nodes | grep -v Ready
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory
```

### 2. Incident Declaration

#### When to Declare an Incident
- Service unavailable for >5 minutes
- Error rate >5% for >5 minutes
- Performance degradation >50% for >10 minutes
- Data integrity concerns
- Security incidents

#### Declaration Process
1. **Create Incident Channel**
   ```
   Slack: #incident-YYYY-MM-DD-HHMM
   Bridge: +1-XXX-XXX-XXXX
   ```

2. **Notify Stakeholders**
   - Engineering on-call
   - Engineering manager (P0/P1 only)
   - Product manager (customer-facing issues)
   - Customer support (if customers affected)

3. **Create Incident Ticket**
   ```
   Title: [PX] Brief description
   Priority: P0/P1/P2/P3
   Components: [affected services]
   Impact: [user impact description]
   ```

### 3. Incident Response

#### Immediate Actions (First 15 minutes)

1. **Assign Incident Commander**
   - On-call engineer becomes IC by default
   - IC coordinates all response activities
   - IC communicates with stakeholders

2. **Initial Triage**
   ```bash
   # Check overall system health
   kubectl cluster-info
   kubectl get componentstatuses
   
   # Check critical services
   kubectl get deployments -n ml-platform
   kubectl get services -n ml-platform
   
   # Check recent events
   kubectl get events --sort-by='.lastTimestamp' | tail -20
   ```

3. **Gather Information**
   - What services are affected?
   - When did the issue start?
   - What changed recently?
   - Are there any error patterns?

4. **Initial Communication**
   ```
   Status Page Update:
   "We are investigating reports of issues with [service]. 
   We will provide updates as we learn more."
   ```

#### Investigation Phase

1. **Check Monitoring Dashboards**
   - Grafana ML Platform Overview
   - Infrastructure metrics
   - Application logs
   - Error rates and latency

2. **Examine Recent Changes**
   ```bash
   # Check recent deployments
   kubectl rollout history deployment -n ml-platform
   
   # Check recent configuration changes
   kubectl get events --field-selector type=Warning
   
   # Check Git commits
   git log --oneline --since="2 hours ago"
   ```

3. **Analyze Logs**
   ```bash
   # Application logs
   kubectl logs -n ml-platform deployment/ml-inference-api --tail=100
   
   # System logs
   kubectl logs -n kube-system deployment/coredns
   
   # Check for errors
   kubectl logs -n ml-platform --selector=app=ml-platform --tail=500 | grep -i error
   ```

4. **Database Health Check**
   ```bash
   # PostgreSQL health
   kubectl exec -n ml-platform deployment/postgres -- psql -U postgres -c "SELECT 1;"
   
   # Redis health
   kubectl exec -n ml-platform deployment/redis -- redis-cli ping
   
   # Check connection counts
   kubectl exec -n ml-platform deployment/postgres -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
   ```

#### Mitigation Strategies

1. **Traffic Management**
   ```bash
   # Scale up affected services
   kubectl scale deployment ml-inference-api --replicas=10 -n ml-platform
   
   # Enable circuit breakers
   kubectl annotate service ml-inference-api circuit-breaker=enabled -n ml-platform
   
   # Route traffic to healthy instances
   kubectl label pod ml-inference-api-xxx health=degraded -n ml-platform
   ```

2. **Rollback Procedures**
   ```bash
   # Rollback deployment
   kubectl rollout undo deployment/ml-inference-api -n ml-platform
   
   # Check rollback status
   kubectl rollout status deployment/ml-inference-api -n ml-platform
   
   # Verify health after rollback
   kubectl get pods -n ml-platform -l app=ml-inference-api
   ```

3. **Database Recovery**
   ```bash
   # Point-in-time recovery (if needed)
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier ml-platform-prod \
     --target-db-instance-identifier ml-platform-recovery \
     --restore-time 2023-XX-XX:XX:XX:XX
   
   # Failover to read replica
   aws rds promote-read-replica \
     --db-instance-identifier ml-platform-read-replica
   ```

4. **Failover to Secondary Region**
   ```bash
   # Update DNS to point to secondary region
   aws route53 change-resource-record-sets \
     --hosted-zone-id Z123456789 \
     --change-batch file://failover-changeset.json
   
   # Scale up secondary region
   kubectl scale deployment ml-inference-api --replicas=20 -n ml-platform
   ```

### 4. Communication During Incident

#### Internal Communication
- **Every 15 minutes** for P0 incidents
- **Every 30 minutes** for P1 incidents
- **Hourly** for P2 incidents

#### External Communication
- **Status page updates** within 15 minutes
- **Customer notifications** for customer-facing issues
- **Partner notifications** if integrations affected

#### Communication Template
```
Time: [timestamp]
Status: [investigating/identified/monitoring/resolved]
Impact: [brief description of user impact]
Next Update: [when next update will be provided]

Details:
[Technical details for internal audience]
```

### 5. Resolution and Recovery

#### Verification Steps
1. **Service Health Checks**
   ```bash
   # Check all pods are running
   kubectl get pods -n ml-platform
   
   # Check service endpoints
   kubectl get endpoints -n ml-platform
   
   # Test critical user journeys
   curl -f https://api.ml-platform.com/health
   ```

2. **Performance Validation**
   ```bash
   # Check response times
   curl -w "@curl-format.txt" -s -o /dev/null https://api.ml-platform.com/models
   
   # Check error rates
   kubectl logs -n ml-platform deployment/ml-inference-api | grep -c ERROR
   ```

3. **Data Integrity Checks**
   ```sql
   -- Check recent transactions
   SELECT COUNT(*) FROM transactions WHERE created_at > NOW() - INTERVAL '1 hour';
   
   -- Verify critical data
   SELECT COUNT(*) FROM models WHERE status = 'active';
   ```

#### Final Communication
```
Status: RESOLVED
Time: [timestamp]

We have resolved the issue affecting [service]. All systems are now operating normally.

Summary:
- Issue started at [time]
- Root cause: [brief description]
- Resolution: [what was done to fix it]
- Impact: [summary of user impact]

We will be conducting a post-incident review to prevent similar issues in the future.
```

### 6. Post-Incident Activities

#### Immediate (Within 24 hours)
1. **Create post-incident ticket**
2. **Schedule post-mortem meeting**
3. **Gather timeline and metrics**
4. **Preserve logs and evidence**

#### Post-Mortem Process
1. **Timeline reconstruction**
2. **Root cause analysis**
3. **Impact assessment**
4. **Action items identification**
5. **Process improvements**

## Disaster Recovery Scenarios

### Complete Region Failure

#### Detection
- All health checks failing in primary region
- No response from regional endpoints
- AWS service health dashboard shows issues

#### Response
1. **Immediate Assessment** (5 minutes)
   ```bash
   # Check AWS service health
   aws health describe-events --filter services=EC2,RDS,EKS
   
   # Test connectivity to secondary region
   aws sts get-caller-identity --region us-east-1
   ```

2. **Activate Secondary Region** (15 minutes)
   ```bash
   # Switch kubectl context
   aws eks update-kubeconfig --region us-east-1 --name ml-platform-secondary
   
   # Scale up secondary region services
   kubectl apply -k infra/deployments/cloud/aws/manifests/prod-secondary/
   
   # Update DNS to point to secondary region
   aws route53 change-resource-record-sets --hosted-zone-id Z123456789 \
     --change-batch file://secondary-region-changeset.json
   ```

3. **Data Recovery** (30 minutes)
   ```bash
   # Promote read replicas
   aws rds promote-read-replica --db-instance-identifier ml-platform-secondary
   
   # Restore from latest backup if needed
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier ml-platform-restored \
     --db-snapshot-identifier ml-platform-latest-snapshot
   ```

### Database Corruption

#### Detection
- Data integrity check failures
- Application errors related to data
- Inconsistent query results

#### Response
1. **Stop Write Operations** (immediate)
   ```bash
   # Scale down write services
   kubectl scale deployment ml-inference-api --replicas=0 -n ml-platform
   
   # Enable read-only mode
   kubectl patch configmap app-config -p '{"data":{"read_only":"true"}}' -n ml-platform
   ```

2. **Assess Corruption Scope** (15 minutes)
   ```sql
   -- Check table integrity
   VACUUM VERBOSE ANALYZE;
   
   -- Verify constraints
   SELECT conname, conrelid::regclass FROM pg_constraint WHERE NOT convalidated;
   ```

3. **Restore from Backup** (30-60 minutes)
   ```bash
   # Point-in-time recovery
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier ml-platform-prod \
     --target-db-instance-identifier ml-platform-recovery \
     --restore-time [last-known-good-time]
   ```

## Emergency Contacts

### Engineering Team
- **SRE On-Call:** +1-XXX-XXX-XXXX (PagerDuty)
- **Engineering Manager:** +1-XXX-XXX-XXXX
- **CTO:** +1-XXX-XXX-XXXX (P0 only)

### External Services
- **AWS Support:** +1-XXX-XXX-XXXX (Enterprise)
- **PagerDuty Support:** +1-XXX-XXX-XXXX
- **Slack Support:** support@slack.com

### Customer Communication
- **Support Team Lead:** +1-XXX-XXX-XXXX
- **Customer Success:** +1-XXX-XXX-XXXX

## Tools and Resources

### Monitoring
- **Grafana:** https://grafana.ml-platform.com
- **Prometheus:** https://prometheus.ml-platform.com
- **Jaeger:** https://jaeger.ml-platform.com
- **Status Page:** https://status.ml-platform.com

### Documentation
- **Runbooks:** https://runbooks.ml-platform.com
- **Architecture Docs:** https://docs.ml-platform.com
- **API Docs:** https://api.ml-platform.com/docs

### Emergency Procedures
- **AWS Console:** https://console.aws.amazon.com
- **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Disaster Recovery Plan:** https://docs.ml-platform.com/dr

## Testing and Validation

### Monthly Drills
- **First Friday:** Database failover drill
- **Second Friday:** Application rollback drill
- **Third Friday:** Regional failover drill
- **Fourth Friday:** Full disaster recovery drill

### Validation Checklist
- [ ] All critical services responding
- [ ] Database connections healthy
- [ ] Authentication working
- [ ] Key user workflows functional
- [ ] Monitoring and alerting operational
- [ ] Logs being collected
- [ ] Backups running successfully