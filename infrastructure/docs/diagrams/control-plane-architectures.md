# Control Plane Architecture Diagrams

## Single Control Plane Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                SINGLE CONTROL PLANE                                 │
└─────────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │          CLIENT ACCESS              │
                    │                                     │
                    │  kubectl, applications, etc.        │
                    └─────────────────┬───────────────────┘
                                      │
                                      ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                           CONTROL PLANE NODE                                    │
    │                      (data-platform-local-control-plane)                        │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
    │  │   API SERVER    │  │   CONTROLLER    │  │   SCHEDULER     │                  │
    │  │                 │  │    MANAGER      │  │                 │                  │
    │  │  • REST API     │  │                 │  │  • Pod          │                  │
    │  │  • Auth         │  │  • Deployments  │  │    Scheduling   │                  │
    │  │  • Admission    │  │  • Services     │  │  • Resource     │                  │
    │  │  • Validation   │  │  • Endpoints    │  │    Allocation   │                  │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
    │  │      ETCD       │  │    COREDNS      │  │  INGRESS NGINX  │                  │
    │  │                 │  │                 │  │                 │                  │
    │  │  • Cluster      │  │  • DNS          │  │  • HTTP/HTTPS   │                  │
    │  │    State        │  │    Resolution   │  │    Routing      │                  │
    │  │  • Config       │  │  • Service      │  │  • SSL          │                  │
    │  │  • Secrets      │  │    Discovery    │  │    Termination  │                  │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
    │                                                                                 │
    │  Resources: 2 CPU, 4GB RAM                                                      │
    │  Labels: node-role=control-plane, ingress-ready=true                            │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                              WORKER NODE                                        │
    │                       (data-platform-local-worker)                              │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
    │  │   MONITORING    │  │   APPLICATIONS  │  │   DATABASES     │                  │
    │  │                 │  │                 │  │                 │                  │
    │  │  • Prometheus   │  │  • ML Apps      │  │  • PostgreSQL   │                  │
    │  │  • Grafana      │  │  • Data Apps    │  │  • Redis        │                  │
    │  │  • AlertManager │  │  • Team Apps    │  │  • MinIO        │                  │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
    │  │     ARGOCD      │  │   CERT-MANAGER  │  │   GPU WORKLOADS │                  │
    │  │                 │  │                 │  │                 │                  │
    │  │  • GitOps       │  │  • SSL Certs    │  │  • ML Training  │                  │
    │  │  • App Deploy   │  │  • Auto Renewal │  │  • Data Proc    │                  │
    │  │  • Sync         │  │  • ACME         │  │  • Inference    │                  │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
    │                                                                                 │
    │  Resources: 4-8 CPU, 8-16GB RAM                                                 │
    │  Labels: node-role=worker, workload-type=data-processing                        │
    └─────────────────────────────────────────────────────────────────────────────────┘

    PROS:                                    CONS:
    ✓ Simple setup                           ✗ Single point of failure
    ✓ Lower resource usage                   ✗ No automatic failover
    ✓ Easy troubleshooting                   ✗ Manual recovery needed
    ✓ Good for development                   ✗ Not production-ready
    
    TOTAL RESOURCES: 6-10 CPU, 12-20GB RAM
```

## High Availability (HA) Control Plane Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            HA CONTROL PLANE (3 NODES)                              │
└─────────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │          CLIENT ACCESS              │
                    │                                     │
                    │  kubectl, applications, etc.        │
                    └─────────────────┬───────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │        LOAD BALANCER                │
                    │                                     │
                    │  • HAProxy (built into kind)        │
                    │  • API Server Load Balancing        │
                    │  • Health Checks                    │
                    │  • Failover Logic                   │
                    └─────────────────┬───────────────────┘
                                      │
                ┌─────────────────────┼─────────────────────┐
                │                     │                     │
                ▼                     ▼                     ▼
    ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
    │   CONTROL PLANE 1   │ │   CONTROL PLANE 2   │ │   CONTROL PLANE 3   │
    │      (LEADER)       │ │    (FOLLOWER)       │ │    (FOLLOWER)       │
    ├─────────────────────┤ ├─────────────────────┤ ├─────────────────────┤
    │                     │ │                     │ │                     │
    │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
    │ │   API SERVER    │ │ │ │   API SERVER    │ │ │ │   API SERVER    │ │
    │ │                 │ │ │ │                 │ │ │ │                 │ │
    │ │  • REST API     │ │ │ │  • REST API     │ │ │ │  • REST API     │ │
    │ │  • Auth         │ │ │ │  • Auth         │ │ │ │  • Auth         │ │
    │ │  • Admission    │ │ │ │  • Admission    │ │ │ │  • Admission    │ │
    │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
    │                     │ │                     │ │                     │
    │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
    │ │   CONTROLLER    │ │ │ │   CONTROLLER    │ │ │ │   CONTROLLER    │ │
    │ │    MANAGER      │ │ │ │    MANAGER      │ │ │ │    MANAGER      │ │
    │ │   (ACTIVE)      │ │ │ │   (STANDBY)     │ │ │ │   (STANDBY)     │ │
    │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
    │                     │ │                     │ │                     │
    │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
    │ │   SCHEDULER     │ │ │ │   SCHEDULER     │ │ │ │   SCHEDULER     │ │
    │ │   (ACTIVE)      │ │ │ │   (STANDBY)     │ │ │ │   (STANDBY)     │ │
    │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
    │                     │ │                     │ │                     │
    │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
    │ │  ETCD (LEADER)  │◄┼─┼►│ ETCD (FOLLOWER) │◄┼─┼►│ ETCD (FOLLOWER) │ │
    │ │                 │ │ │ │                 │ │ │ │                 │ │
    │ │  • Cluster      │ │ │ │  • Replication  │ │ │ │  • Replication  │ │
    │ │    State        │ │ │ │  • Consensus    │ │ │ │  • Consensus    │ │
    │ │  • Config       │ │ │ │  • Backup       │ │ │ │  • Backup       │ │
    │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
    │                     │ │                     │ │                     │
    │ Resources:          │ │ Resources:          │ │ Resources:          │
    │ 2 CPU, 4GB RAM      │ │ 2 CPU, 4GB RAM      │ │ 2 CPU, 4GB RAM      │
    │                     │ │                     │ │                     │
    │ Labels:             │ │ Labels:             │ │ Labels:             │
    │ node-role=cp        │ │ node-role=cp        │ │ node-role=cp        │
    │ control-plane-id=1  │ │ control-plane-id=2  │ │ control-plane-id=3  │
    │ ingress-ready=true  │ │                     │ │                     │
    └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
                                      │
                                      ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                           INFRASTRUCTURE NODE                                   │
    │                      (data-platform-local-infra)                                │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
    │  │   MONITORING    │  │     ARGOCD      │  │   CERT-MANAGER  │                  │
    │  │                 │  │                 │  │                 │                  │
    │  │  • Prometheus   │  │  • GitOps       │  │  • SSL Certs    │                  │
    │  │  • Grafana      │  │  • App Deploy   │  │  • Auto Renewal │                  │
    │  │  • AlertManager │  │  • Sync         │  │  • ACME         │                  │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
    │  │   DATABASES     │  │    STORAGE      │  │   NETWORKING    │                  │
    │  │                 │  │                 │  │                 │                  │
    │  │  • PostgreSQL   │  │  • MinIO        │  │  • Service      │                  │
    │  │  • Redis        │  │  • PV Storage   │  │    Mesh         │                  │
    │  │  • Backup       │  │  • Backup       │  │  • Network      │                  │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
    │                                                                                 │
    │  Resources: 4 CPU, 8GB RAM                                                      │
    │  Labels: node-role=infra                                                        │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                             WORKLOAD NODE                                       │
    │                       (data-platform-local-workload)                           │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
    │  │   ML WORKLOADS  │  │  DATA PROCESSING│  │   APPLICATIONS  │                │
    │  │                 │  │                 │  │                 │                │
    │  │  • Training     │  │  • ETL Jobs     │  │  • Team Apps    │                │
    │  │  • Inference    │  │  • Data Prep    │  │  • APIs         │                │
    │  │  • Model Serve  │  │  • Analytics    │  │  • Services     │                │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
    │                                                                                 │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
    │  │   GPU SUPPORT   │  │  BATCH JOBS     │  │   SCALING       │                │
    │  │                 │  │                 │  │                 │                │
    │  │  • CUDA         │  │  • Cron Jobs    │  │  • HPA          │                │
    │  │  • TensorFlow   │  │  • Spark        │  │  • VPA          │                │
    │  │  • PyTorch      │  │  • Airflow      │  │  • Cluster      │                │
    │  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
    │                                                                                 │
    │  Resources: 4-8 CPU, 16-32GB RAM, GPU (optional)                              │
    │  Labels: node-role=workload, workload-type=data-processing                     │
    └─────────────────────────────────────────────────────────────────────────────────┘

    PROS:                                    CONS:
    ✓ High availability                      ✗ Complex setup
    ✓ Automatic failover                     ✗ Higher resource usage
    ✓ Production-ready                       ✗ Network complexity
    ✓ Survives node failures                 ✗ Harder troubleshooting
    
    TOTAL RESOURCES: 12-16 CPU, 28-44GB RAM

    ETCD QUORUM: Requires 2 out of 3 nodes for cluster operations
    FAILOVER: Automatic API server failover via load balancer
    RECOVERY: Automatic etcd leader election and data consistency
```

## Comparison Matrix

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              COMPARISON MATRIX                                      │
├─────────────────────────┬─────────────────────────┬─────────────────────────────────┤
│        ASPECT           │   SINGLE CONTROL PLANE  │    HA CONTROL PLANE (3 NODES)   │
├─────────────────────────┼─────────────────────────┼─────────────────────────────────┤
│ Total Nodes             │            2            │               5                 │
│ Control Plane Nodes     │            1            │               3                 │
│ Worker Nodes            │            1            │               2                 │
│ API Server Endpoints    │            1            │               3                 │
│ etcd Instances          │            1            │               3                 │
│ Load Balancer           │           No            │              Yes                │
│ Automatic Failover      │           No            │              Yes                │
│ Surviving Node Failures │            0            │               1                 │
│ Setup Complexity        │          Low            │             High                │
│ Resource Usage          │          Low            │             High                │
│ Troubleshooting         │          Easy           │           Complex               │
│ Production Ready        │           No            │              Yes                │
│ Development Suitable    │          Yes            │             Yes                 │
│ Cost                    │          Low            │             High                │
└─────────────────────────┴─────────────────────────┴─────────────────────────────────┘
```

## Failure Scenarios

### Single Control Plane Failure

```
    Normal Operation                     Control Plane Failure
    ────────────────────                 ──────────────────────
    
    CLIENT ───► CONTROL PLANE            CLIENT ───► ❌ CONTROL PLANE
               ↓                                      ↓
            WORKER NODE                            WORKER NODE
                                                  (keeps running existing pods,
                                                   but no new deployments)
    
    RESULT: Complete cluster management failure
    RECOVERY: Manual intervention required
```

### HA Control Plane Failure

```
    Normal Operation                     One Control Plane Failure
    ────────────────────                 ──────────────────────────
    
    CLIENT ───► LOAD BALANCER            CLIENT ───► LOAD BALANCER
               ↓                                      ↓
         CP1 + CP2 + CP3                        CP1 + ❌ + CP3
               ↓                                      ↓
           WORKER NODES                           WORKER NODES
    
    RESULT: Automatic failover, minimal disruption
    RECOVERY: Automatic, no manual intervention
```

---

**Recommendation for Your Use Case:**

- **Development/Testing**: Use Single Control Plane (saves resources for GPU workloads)
- **Production/Critical**: Use HA Control Plane (ensures availability)
- **Hybrid**: Start with Single, migrate to HA for production deployment
