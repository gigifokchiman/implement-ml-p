# Helm values template managed by Terraform
# This template is rendered by Terraform and passed to Helm

app:
  name: "${app_name}"
  namespace: "${namespace}"
  environment: "${environment}"
  version: "1.0.0"

# Database configuration (controlled by Terraform)
database:
  enabled: ${database_enabled}
  %{ if database_enabled }
  postgresql:
    auth:
      enablePostgresUser: true
      postgresPassword: "changeme123"
      username: "${app_name}_user"
      password: "changeme123" 
      database: "${app_name}_db"
    primary:
      persistence:
        enabled: false  # Local development
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi
  %{ endif }

# Cache configuration (controlled by Terraform)
cache:
  enabled: ${cache_enabled}
  %{ if cache_enabled }
  redis:
    auth:
      enabled: false  # Local development
    master:
      persistence:
        enabled: false
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
  %{ endif }

# Storage configuration (controlled by Terraform)
storage:
  enabled: ${storage_enabled}
  %{ if storage_enabled }
  minio:
    auth:
      rootUser: "admin"
      rootPassword: "changeme123"
    defaultBuckets: "${app_name}-data,${app_name}-artifacts,${app_name}-models"
    persistence:
      enabled: false  # Local development
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  %{ endif }

# Monitoring configuration (controlled by Terraform)
monitoring:
  enabled: ${monitoring_enabled}
  %{ if monitoring_enabled }
  prometheus:
    server:
      persistence:
        enabled: false
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 1Gi
    alertmanager:
      enabled: false
    pushgateway:
      enabled: false
    nodeExporter:
      enabled: false
  %{ endif }

# Application services
services:
  api:
    enabled: true
    image:
      repository: "nginx"
      tag: "alpine"
      pullPolicy: IfNotPresent
    port: 8080
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "${app_name}.local"
      paths:
        - path: /
          pathType: Prefix

# Security configurations
networkPolicies:
  enabled: true
  defaultDeny: true
  allowDNS: true

podSecurity:
  enabled: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000

# Resource management
resourceQuota:
  enabled: true
  hard:
    requests.cpu: "1"
    requests.memory: "2Gi"
    limits.cpu: "2"
    limits.memory: "4Gi"

# Environment-specific overrides
%{ if environment == "local" }
# Local development settings
autoscaling:
  enabled: false

replicaCount: 1
%{ endif }

%{ if environment == "prod" }
# Production settings
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

replicaCount: 3
%{ endif }