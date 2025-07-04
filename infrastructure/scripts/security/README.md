# Security Scripts

Scripts for implementing team isolation, RBAC, and Kubernetes-native security.

## Scripts

- **`deploy-single-cluster-isolation.sh`** - Set up team namespaces, resource quotas, and RBAC
- **`deploy-kubernetes-security.sh`** - Deploy comprehensive security policies (TLS, audit, network policies)

## What They Provide

### Team Isolation

- Resource quotas per team (CPU, memory, storage)
- RBAC policies for team boundaries
- Network policies for isolation
- Proper labeling for cost attribution

### Security Hardening

- TLS termination at ingress
- Kubernetes audit logging
- Network policies between teams
- Rate limiting per endpoint
- Pod security standards

Run these after basic platform deployment to secure your environment.
