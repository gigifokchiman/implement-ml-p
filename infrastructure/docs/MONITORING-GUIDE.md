# ML Platform Monitoring Guide

## 🎯 Overview

This guide shows development teams how to add monitoring to their applications deployed on the ML Platform. The
monitoring infrastructure (Prometheus, Grafana, AlertManager) is managed by Terraform, while teams use Kustomize to
configure what metrics to send.

## 🏗️ Architecture

### **Infrastructure Layer (Terraform - Platform Team)**

- ✅ **Prometheus Server**: Collects metrics automatically
- ✅ **Grafana Dashboards**: Pre-built ML Platform dashboards
- ✅ **AlertManager**: Platform-wide alerting
- ✅ **ServiceMonitors**: Auto-discover services with labels
- ✅ **Storage & Security**: Persistent storage, network policies

### **Application Layer (Kustomize - Development Teams)**

- 🔧 **Metrics Endpoints**: Your app exposes `/metrics`
- 🔧 **Service Labels**: Add labels for auto-discovery
- 🔧 **Custom Dashboards**: Team-specific Grafana dashboards
- 🔧 **Application Alerts**: Service-level PrometheusRules

## 📊 How to Add Monitoring to Your Service

### **Step 1: Expose Metrics in Your Application**

Add a metrics endpoint to your application:

```python
# Python example with Prometheus client
from prometheus_client import Counter, Histogram, generate_latest
from flask import Flask, Response

app = Flask(__name__)

# Define custom metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')


@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype='text/plain')


# ML Training specific metrics
TRAINING_LOSS = Histogram('training_loss', 'Current training loss')
TRAINING_ACCURACY = Histogram('training_accuracy', 'Current training accuracy')
EPOCHS_COMPLETED = Counter('training_epochs_completed', 'Number of epochs completed')
```

```javascript
// Node.js example with prom-client
const prometheus = require('prom-client');
const express = require('express');

const register = new prometheus.Registry();

// Custom metrics
const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'endpoint']
});

register.registerMetric(httpRequestDuration);

app.get('/metrics', (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(register.metrics());
});
```

### **Step 2: Add Discovery Labels to Your Kubernetes Service**

Update your Kustomize service manifests:

```yaml
# kustomize/base/backend/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-backend-api
  labels:
    app.kubernetes.io/name: ml-backend-api
    app.kubernetes.io/component: backend              # ← Service type for ServiceMonitor
    prometheus.io/scrape: "true"                      # ← Enable scraping
    prometheus.io/port: "8080"                        # ← Metrics port
    prometheus.io/path: "/metrics"                    # ← Metrics path (optional)
spec:
  selector:
    app: ml-backend-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
    - name: metrics                                     # ← Metrics port
      port: 8080
      targetPort: 8080
```

### **Step 3: Deploy to Appropriate VPC Subnet**

Deploy your service to the correct namespace based on its role:

```bash
# Backend API → Private subnet
kubectl apply -k kustomize/overlays/local -n ml-platform-local-private

# Frontend app → Public subnet  
kubectl apply -k kustomize/overlays/local -n ml-platform-local-public

# ML training job → ML workload subnet
kubectl apply -k kustomize/overlays/local -n ml-platform-local-ml-workload

# Data processing → Data processing subnet
kubectl apply -k kustomize/overlays/local -n ml-platform-local-data-processing
```

### **Step 4: Verify Auto-Discovery**

Check that Prometheus discovered your service:

```bash
# Port forward to Prometheus
kubectl port-forward -n ml-platform-local-monitoring svc/prometheus-prometheus 9090:9090

# Open http://localhost:9090 → Status → Targets
# Your service should appear in the list
```

## 🎯 Service Discovery by Component Type

The platform automatically discovers services based on the `app.kubernetes.io/component` label:

| Component Label                                 | ServiceMonitor       | Use For                 | Namespaces Monitored   |
|-------------------------------------------------|----------------------|-------------------------|------------------------|
| `backend`, `api`, `web-service`, `microservice` | backend-services     | REST APIs, web services | private subnet         |
| `frontend`, `ui`, `web-app`                     | frontend-services    | Frontend applications   | public subnet          |
| `ml-training`, `ml-inference`, `ml-workload`    | ml-training-jobs     | ML training/inference   | ml-workload subnet     |
| `data-processing`, `etl`, `batch-job`           | data-processing-jobs | Data pipelines          | data-processing subnet |
| `database`, `cache`, `postgresql`, `redis`      | database-services    | Data services           | database subnet        |
| `storage`, `minio`, `object-storage`            | storage-services     | Storage services        | private subnet         |

## 📈 Example Service Configurations

### **Backend API Service**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: user-api
  labels:
    app.kubernetes.io/component: backend
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  ports:
    - name: metrics
      port: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-api
spec:
  template:
    spec:
      containers:
        - name: api
          image: user-api:latest
          ports:
            - containerPort: 8080
              name: metrics
```

### **ML Training Job**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: model-training
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/component: ml-training
        prometheus.io/scrape: "true"
    spec:
      containers:
        - name: trainer
          image: ml-trainer:latest
          ports:
            - containerPort: 9090
              name: metrics
          # Your training code exposes:
          # - training_loss
          # - training_accuracy  
          # - training_epochs_completed
          # - training_samples_processed_total
```

### **Data Processing Pipeline**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-etl
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app.kubernetes.io/component: data-processing
            prometheus.io/scrape: "true"
        spec:
          containers:
            - name: etl
              image: data-processor:latest
              ports:
                - containerPort: 9090
                  name: metrics
              # Your ETL code exposes:
              # - data_records_processed_total
              # - data_processing_errors_total
              # - data_queue_depth
```

## 📊 Custom Dashboards

Teams can create custom Grafana dashboards using ConfigMaps:

```yaml
# kustomize/base/monitoring/dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-team-dashboard
  namespace: ml-platform-local-monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |
    {
      "dashboard": {
        "title": "My Team Dashboard",
        "panels": [
          {
            "title": "Request Rate",
            "targets": [
              {
                "expr": "rate(http_requests_total{service=\"my-service\"}[5m])"
              }
            ]
          }
        ]
      }
    }
```

## 🚨 Custom Alerts

Create service-specific alerts with PrometheusRules:

```yaml
# kustomize/base/monitoring/alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-service-alerts
  namespace: ml-platform-local-monitoring
  labels:
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
    - name: my-service.rules
      rules:
        - alert: MyServiceHighErrorRate
          expr: rate(http_requests_total{service="my-service",status=~"5.."}[5m]) > 0.1
          for: 5m
          labels:
            severity: warning
            team: my-team
          annotations:
            summary: "High error rate on my service"
            description: "Error rate is {{ $value | humanizePercentage }}"
```

## 🔍 Available Dashboards

The platform provides pre-built dashboards:

### **1. ML Platform Overview**

- Platform health status
- Active ML training jobs
- CPU/Memory usage by service
- Database connections
- Storage usage

### **2. ML Training Jobs**

- Training job status (active/succeeded/failed)
- Training loss and accuracy metrics
- GPU utilization
- Data processing rate
- Epochs completed

### **3. Data Processing Pipelines**

- Pipeline status
- Records processed per hour
- Processing rate and error rate
- Queue depth

### **4. Infrastructure Overview**

- Cluster resource usage
- Pod distribution by namespace
- Storage usage by PVC
- Network I/O

## 📊 Common Metrics to Expose

### **Application Metrics**

```python
# HTTP server metrics
http_requests_total = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
http_request_duration_seconds = Histogram('http_request_duration_seconds', 'HTTP request duration')

# Database metrics  
database_connections_active = Gauge('database_connections_active', 'Active database connections')
database_query_duration_seconds = Histogram('database_query_duration_seconds', 'Database query duration')

# Custom business metrics
user_registrations_total = Counter('user_registrations_total', 'Total user registrations')
api_rate_limits_exceeded_total = Counter('api_rate_limits_exceeded_total', 'Rate limit violations')
```

### **ML Training Metrics**

```python
# Training progress
training_loss = Gauge('training_loss', 'Current training loss', ['model_name', 'epoch'])
training_accuracy = Gauge('training_accuracy', 'Current training accuracy', ['model_name', 'epoch'])
training_epochs_completed = Counter('training_epochs_completed', 'Completed epochs', ['model_name'])

# Data processing
training_samples_processed_total = Counter('training_samples_processed_total', 'Training samples processed',
                                           ['dataset'])
training_batch_duration_seconds = Histogram('training_batch_duration_seconds', 'Training batch duration')

# Resource usage
gpu_utilization_percent = Gauge('gpu_utilization_percent', 'GPU utilization', ['gpu_id'])
model_memory_usage_bytes = Gauge('model_memory_usage_bytes', 'Model memory usage', ['model_name'])
```

### **Data Processing Metrics**

```python
# Processing throughput
data_records_processed_total = Counter('data_records_processed_total', 'Records processed', ['pipeline', 'stage'])
data_processing_errors_total = Counter('data_processing_errors_total', 'Processing errors', ['pipeline', 'error_type'])

# Queue metrics
data_queue_depth = Gauge('data_queue_depth', 'Queue depth', ['queue_name'])
data_processing_duration_seconds = Histogram('data_processing_duration_seconds', 'Processing duration', ['pipeline'])

# Data quality
data_validation_failures_total = Counter('data_validation_failures_total', 'Validation failures', ['validation_rule'])
```

## 🚀 Quick Start Commands

```bash
# 1. Deploy your service with monitoring labels
kubectl apply -k kustomize/overlays/local -n ml-platform-local-private

# 2. Check if Prometheus discovered your service
kubectl port-forward -n ml-platform-local-monitoring svc/prometheus-prometheus 9090:9090
# → Open http://localhost:9090/targets

# 3. Access Grafana dashboards  
kubectl port-forward -n ml-platform-local-monitoring svc/prometheus-grafana 3000:80
# → Open http://localhost:3000 (admin/admin123)

# 4. View available ServiceMonitors
kubectl get servicemonitors -n ml-platform-local-monitoring

# 5. Check your custom alerts
kubectl get prometheusrules -n ml-platform-local-monitoring
```

## 🎯 Best Practices

1. **Consistent Labeling**: Always use `app.kubernetes.io/component` for service discovery
2. **Standard Metrics**: Follow Prometheus naming conventions (`_total`, `_seconds`, etc.)
3. **Resource Efficiency**: Don't expose too many high-cardinality metrics
4. **Error Tracking**: Always include error counters for your services
5. **Business Metrics**: Expose metrics that matter for your business logic
6. **Dashboard Organization**: Group related metrics in team-specific dashboards
7. **Alert Tuning**: Start with warnings, tune thresholds based on historical data

## 🔧 Troubleshooting

### **Service Not Discovered**

1. Check service has correct labels: `prometheus.io/scrape: "true"` and `app.kubernetes.io/component`
2. Verify service is in the right namespace for the ServiceMonitor
3. Check Prometheus targets: Status → Targets

### **Metrics Not Appearing**

1. Verify your app exposes `/metrics` endpoint
2. Check the metrics port matches `prometheus.io/port` label
3. Test manually: `curl http://service:port/metrics`

### **Alerts Not Firing**

1. Check PrometheusRule is in monitoring namespace
2. Verify labels include `prometheus: kube-prometheus` and `role: alert-rules`
3. Test alert expression in Prometheus query interface

This monitoring setup provides teams with automatic service discovery, comprehensive dashboards, and proactive alerting
while maintaining clear separation between infrastructure and application concerns! 🚀
