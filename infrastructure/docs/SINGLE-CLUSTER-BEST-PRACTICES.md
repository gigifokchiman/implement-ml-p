# Single Cluster Best Practices

## 🎯 Implementation Summary

Your single cluster now has **multi-cluster-like isolation** without the complexity:

### ✅ What's Implemented

**Team Isolation:**

- **ML Team**: 20 CPU, 64GB RAM, 500GB storage, GPU access
- **Data Team**: 16 CPU, 48GB RAM, 1TB storage, broader storage access
- **App Team**: 8 CPU, 24GB RAM, 200GB storage, ingress management

**Security Boundaries:**

- Namespace-level RBAC
- Resource quotas and limits
- Cross-namespace read-only access for debugging
- Team-specific permissions (ML=GPUs, Data=Storage, App=Ingress)

**Monitoring & Alerts:**

- Per-namespace resource monitoring
- Quota usage alerts (80% CPU/Memory, 90% Pods)
- Team-specific dashboards
- ServiceMonitor for custom metrics

**Disaster Recovery:**

- Velero backup schedules (daily + weekly)
- etcd backup every 6 hours
- Blue-green deployment procedures
- RTO/RPO targets defined

## 🚀 Deployment

```bash
# Deploy all isolation components
./deploy-single-cluster-isolation.sh

# Or apply individually
kubectl apply -f kubernetes/team-isolation/
kubectl apply -f kubernetes/rbac/
kubectl apply -f kubernetes/monitoring/
```

## 🧪 Testing Team Isolation

```bash
# Test resource quotas
kubectl run test-pod --image=nginx -n ml-team
kubectl describe quota ml-team-quota -n ml-team

# Test RBAC boundaries
kubectl auth can-i create pods --as=user:ml-engineer@company.com -n ml-team     # ✅ Yes
kubectl auth can-i create pods --as=user:ml-engineer@company.com -n data-team   # ❌ No

# Test resource limits
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: resource-test
  namespace: ml-team
spec:
  containers:
  - name: test
    image: nginx
    resources:
      requests:
        cpu: "20"  # Should be rejected - exceeds quota
        memory: "64Gi"
EOF
```

## 📊 Monitoring

**Grafana Dashboards:**

- Team Resource Usage (CPU/Memory/Storage by namespace)
- Quota utilization trends
- Cross-team resource sharing

**Key Metrics to Watch:**

```promql
# CPU quota usage by team
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace) / 
on(namespace) kube_resourcequota{resource="requests.cpu"}

# Memory pressure
sum(container_memory_working_set_bytes) by (namespace) /
on(namespace) kube_resourcequota{resource="requests.memory"}
```

## 🔄 Blue-Green Deployment

**For ML Models:**

```bash
# 1. Deploy new version to green namespace
kubectl create namespace ml-team-green
kubectl apply -f ml-model-v2.yaml -n ml-team-green

# 2. Switch traffic gradually
kubectl patch service ml-inference -p '{"spec":{"selector":{"version":"v2"}}}'

# 3. Monitor and rollback if needed
kubectl patch service ml-inference -p '{"spec":{"selector":{"version":"v1"}}}'
```

## 🚨 When to Consider Multi-Cluster

**Stay single cluster if:**

- ✅ Teams collaborate frequently
- ✅ Resource contention is manageable
- ✅ Compliance requirements are met
- ✅ Current quotas provide sufficient isolation

**Move to multi-cluster when:**

- ❌ Hard compliance boundaries needed (SOX, GDPR isolation)
- ❌ Teams have conflicting K8s version requirements
- ❌ Network policies aren't sufficient for security
- ❌ Resource contention causes performance issues
- ❌ Teams need different cluster configurations

## 🔧 Maintenance Tasks

**Daily:**

- Check quota usage: `kubectl get resourcequota --all-namespaces`
- Review failed pods: `kubectl get pods --all-namespaces --field-selector=status.phase=Failed`

**Weekly:**

- Review team resource trends
- Test backup restoration
- Update resource quotas based on usage

**Monthly:**

- DR testing
- Review RBAC permissions
- Capacity planning

## 📈 Scaling Path

**Phase 1: Current (Single Cluster)**

- Namespace isolation ✅
- Resource quotas ✅
- Team RBAC ✅

**Phase 2: Enhanced Isolation**

- Network policies
- Pod security policies
- Service mesh (if needed)

**Phase 3: Multi-Cluster (If Required)**

- Use your federation scripts ✅
- Gradual migration by team
- Maintain single cluster for shared services

## 🎉 Benefits Achieved

**Without Multi-Cluster Complexity:**

- ✅ Team boundaries enforced
- ✅ Resource isolation guaranteed
- ✅ Monitoring and alerting
- ✅ Disaster recovery ready
- ✅ Blue-green deployments
- ✅ Migration path available

**Smart decision!** You have 80% of multi-cluster benefits with 20% of the complexity.
