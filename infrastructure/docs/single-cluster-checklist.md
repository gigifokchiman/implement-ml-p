✅ Single Cluster Done Right: Complete Checklist
🎯 Team Isolation (Without Multi-Cluster)
Namespace Strategy
bash✅ Create dedicated namespaces per team
kubectl create namespace ml-team
kubectl create namespace data-team
kubectl create namespace shared-services

✅ Use consistent labeling
kubectl label namespace ml-team team=ml
kubectl label namespace data-team team=data
Resource Quotas & Limits
yaml✅ Hard resource limits per team
apiVersion: v1
kind: ResourceQuota
metadata:
name: ml-team-quota
namespace: ml-team
spec:
hard:
requests.cpu: "32"           # Guaranteed CPU
requests.memory: "128Gi"     # Guaranteed memory
requests.nvidia.com/gpu: "8" # Guaranteed GPUs
limits.cpu: "64"             # Max CPU burst
limits.memory: "256Gi"       # Max memory burst
persistentvolumeclaims: "10" # Storage limits
services: "20"               # Service limits
secrets: "50"                # Secret limits

✅ Node-level isolation
kubectl label nodes node1 node2 team=ml workload=gpu
kubectl label nodes node3 node4 team=data workload=cpu

✅ Pod resource requirements (enforce limits)
resources:
requests:
cpu: "2"
memory: "4Gi"
limits:
cpu: "4"
memory: "8Gi"
🔒 Security & Access Control
RBAC (Role-Based Access Control)
yaml✅ Team-specific roles
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
namespace: ml-team
name: ml-developer
rules:

- apiGroups: ["", "apps", "extensions"]
  resources: ["pods", "deployments", "services", "configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

✅ Bind users to roles
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
name: ml-team-binding
namespace: ml-team
subjects:

- kind: User
  name: ml-team-lead@company.com
  roleRef:
  kind: Role
  name: ml-developer
  apiGroup: rbac.authorization.k8s.io

✅ Service account isolation
kubectl create serviceaccount ml-workloads -n ml-team
Network Policies
yaml✅ Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: default-deny
namespace: ml-team
spec:
podSelector: {}
policyTypes:

- Ingress
- Egress

✅ Explicit allow rules only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: ml-team-policy
namespace: ml-team
spec:
podSelector: {}
policyTypes:

- Ingress
- Egress
  ingress:
- from:
    - namespaceSelector:
      matchLabels:
      name: ml-team
      egress:
- to:
    - namespaceSelector:
      matchLabels:
      name: shared-services # Allow monitoring
- to: []  # Allow external traffic
  ports:
    - protocol: TCP
      port: 443 # HTTPS only
      📊 Monitoring & Observability
      Team-Specific Monitoring
      yaml✅ Prometheus per-team scraping
- job_name: 'ml-team-pods'
  kubernetes_sd_configs:
    - role: pod
      namespaces:
      names: ['ml-team']
      relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true

✅ Grafana dashboards per team

# Dashboard filters by namespace/team labels

namespace="ml-team"
team="ml"

✅ Alerting per team
groups:

- name: ml-team-alerts
  rules:
    - alert: MLJobFailed
      expr: kube_job_status_failed{namespace="ml-team"} > 0
      annotations:
      summary: "ML job failed in ml-team namespace"
      Logging Strategy
      yaml✅ Centralized logging with team context
      apiVersion: v1
      kind: ConfigMap
      metadata:
      name: fluentd-config
      data:
      fluent.conf: |
      <match kubernetes.var.log.containers.**ml-team**.log>
      @type elasticsearch
      index_name ml-team-logs
      type_name logs
      </match>

      <match kubernetes.var.log.containers.**data-team**.log>
      @type elasticsearch  
      index_name data-team-logs
      type_name logs
      </match>
      ⚡ Performance & Scaling
      Node Affinity & Taints
      yaml✅ GPU nodes for ML team only
      apiVersion: v1
      kind: Node
      metadata:
      name: gpu-node-1
      labels:
      team: ml
      workload: gpu
      spec:
      taints:
    - key: "team"
      value: "ml"
      effect: "NoSchedule"

✅ CPU nodes for data team
apiVersion: v1
kind: Node  
metadata:
name: cpu-node-1
labels:
team: data
workload: cpu
spec:
taints:

- key: "team"
  value: "data"
  effect: "NoSchedule"

✅ Pod scheduling
spec:
nodeSelector:
team: ml
workload: gpu
tolerations:

- key: "team"
  operator: "Equal"
  value: "ml"
  effect: "NoSchedule"
  Auto-Scaling Setup
  yaml✅ Horizontal Pod Autoscaler per team
  apiVersion: autoscaling/v2
  kind: HorizontalPodAutoscaler
  metadata:
  name: ml-training-hpa
  namespace: ml-team
  spec:
  scaleTargetRef:
  apiVersion: apps/v1
  kind: Deployment
  name: ml-training
  minReplicas: 2
  maxReplicas: 20
  metrics:
- type: Resource
  resource:
  name: cpu
  target:
  type: Utilization
  averageUtilization: 70

✅ Cluster Autoscaler with team node groups

# AWS example

--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/ml-cluster
--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/data-cluster
🔄 Deployment & GitOps
ArgoCD Applications per Team
yaml✅ ML team applications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
name: ml-workloads
namespace: argocd
spec:
project: ml-team
source:
repoURL: 'https://github.com/company/ml-manifests'
path: 'production'
targetRevision: 'main'
destination:
server: 'https://kubernetes.default.svc'
namespace: 'ml-team'
syncPolicy:
automated:
prune: true
selfHeal: true

✅ Data team applications  
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
name: data-workloads
namespace: argocd
spec:
project: data-team
source:
repoURL: 'https://github.com/company/data-manifests'
path: 'production'
targetRevision: 'main'
destination:
server: 'https://kubernetes.default.svc'
namespace: 'data-team'
CI/CD Pipeline Isolation
yaml✅ Separate pipelines per team

# .github/workflows/ml-team-deploy.yml

name: ML Team Deploy
on:
push:
paths: ['ml-team/**']
branches: [main]
jobs:
deploy:
runs-on: ubuntu-latest
steps:
- name: Deploy to ML namespace
run: |
kubectl apply -f ml-team/ -n ml-team
💾 Storage & Data Management
Storage Classes per Team
yaml✅ Team-specific storage classes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
name: ml-fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
type: gp3
iops: "10000"
throughput: "1000"
allowedTopologies:

- matchLabelExpressions:
    - key: team
      values: ["ml"]

✅ Persistent Volume Claims with limits
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: ml-training-data
namespace: ml-team
spec:
accessModes: ["ReadWriteOnce"]
storageClassName: "ml-fast-ssd"
resources:
requests:
storage: 1Ti
🛡️ Security & Compliance
TLS & Encryption
yaml✅ TLS termination at ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: ml-api-ingress
namespace: ml-team
annotations:
nginx.ingress.kubernetes.io/ssl-redirect: "true"
cert-manager.io/cluster-issuer: "letsencrypt"
spec:
tls:

- hosts:
    - ml-api.company.com
      secretName: ml-api-tls
      rules:
- host: ml-api.company.com
  http:
  paths:
    - path: /
      backend:
      service:
      name: ml-api-service
      port:
      number: 80

✅ Secrets management
kubectl create secret generic ml-db-credentials \
--from-literal=username=ml-user \
--from-literal=password=secure-password \
-n ml-team
Audit Logging
yaml✅ Kubernetes audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:

- level: RequestResponse
  omitStages: ["RequestReceived"]
  resources:
    - group: ""
      resources: ["pods", "services", "secrets"]
      namespaces: ["ml-team", "data-team"]

✅ Application audit logging

# In your application config

logging:
level: INFO
format: json
audit:
enabled: true
include_user: true
include_timestamp: true
include_action: true
💰 Cost Management
Resource Tracking
bash✅ Cost allocation by namespace/team
kubectl top nodes --selector=team=ml
kubectl top pods -n ml-team --containers

✅ Kubecost or similar for cost visibility

# Shows spend per namespace/team

# Tracks resource efficiency

# Identifies optimization opportunities

Resource Optimization
yaml✅ Pod Disruption Budgets
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
name: ml-training-pdb
namespace: ml-team
spec:
minAvailable: 1
selector:
matchLabels:
app: ml-training

✅ Resource requests = actual usage

# Monitor and adjust based on actual usage

resources:
requests:
cpu: "1.5"      # Based on actual average
memory: "3Gi"   # Based on actual average
limits:
cpu: "3"        # 2x requests for bursts
memory: "6Gi"   # 2x requests for bursts
🚀 Disaster Recovery & Backup
Backup Strategy
bash✅ Velero backups per namespace
velero backup create ml-team-backup \
--include-namespaces ml-team \
--storage-location default

✅ Regular backup schedule
velero schedule create ml-team-daily \
--schedule="0 2 * * *" \
--include-namespaces ml-team

✅ Application data backup

# Database backups

# Model artifact backups

# Training data backups

📋 Single Cluster Success Checklist
✅ Team Isolation Achieved:

Separate namespaces per team
Resource quotas enforced
RBAC configured per team
Network policies isolating teams
Node affinity/taints for workload separation

✅ Security Implemented:

TLS encryption at ingress
Network policies (default deny)
RBAC with least privilege
Secrets management
Audit logging enabled

✅ Monitoring & Observability:

Team-specific Prometheus metrics
Grafana dashboards per team
Centralized logging with team context
Alerting per team/namespace

✅ Performance & Scaling:

HPA configured per application
Cluster autoscaler for nodes
Resource requests/limits tuned
Storage classes optimized per workload

✅ Operational Excellence:

GitOps deployment per team
CI/CD pipeline isolation
Backup strategy implemented
Cost tracking per team
Documentation updated

💡 Key Success Factors
Do This:
bash✅ Start simple, add complexity only when needed
✅ Monitor resource usage and adjust quotas
✅ Document team boundaries and policies
✅ Regular security audits
✅ Cost optimization reviews
✅ Team feedback sessions
Avoid This:
bash❌ Over-engineering before you have problems
❌ Ignoring resource limits (leads to conflicts)
❌ Mixing team workloads on same nodes
❌ Weak network policies
❌ No monitoring/alerting
❌ Manual deployment processes
🎯 When You Know Single Cluster is Working:

✅ Teams deploy independently without conflicts
✅ Resource contention incidents < 1 per month
✅ Clear cost attribution per team
✅ Security audit passes
✅ Upgrade coordination takes < 1 day planning
✅ New team member onboarding < 1 week
✅ Incident response doesn't require cross-team coordination

If all these are true, stick with single cluster! 🚀
