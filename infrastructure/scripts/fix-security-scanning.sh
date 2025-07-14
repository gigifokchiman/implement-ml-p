#!/bin/bash
# Fix security scanning deployment issues

echo "🔧 Fixing security scanning deployment..."

# 1. Clean up failed resources
echo "1. Cleaning up failed resources..."
kubectl delete pvc trivy-cache -n data-platform-security-scanning 2>/dev/null || true
kubectl delete deployment falco -n data-platform-security-scanning 2>/dev/null || true
kubectl delete deployment trivy-server -n data-platform-security-scanning 2>/dev/null || true

# 2. Create a storage class with immediate binding for local dev
echo "2. Creating immediate binding storage class..."
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-local
provisioner: rancher.io/local-path
volumeBindingMode: Immediate
reclaimPolicy: Delete
EOF

# 3. Patch the PVC to use immediate binding storage class
echo "3. Creating fixed PVC with immediate binding..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: trivy-cache
  namespace: data-platform-security-scanning
  labels:
    app.kubernetes.io/name: trivy
    app.kubernetes.io/component: cache
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-local
  resources:
    requests:
      storage: 5Gi
EOF

# 4. Deploy Trivy server manually (temporary fix)
echo "4. Deploying Trivy server..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trivy-server
  namespace: data-platform-security-scanning
  labels:
    app.kubernetes.io/name: trivy
    app.kubernetes.io/component: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: trivy
      app.kubernetes.io/component: server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: trivy
        app.kubernetes.io/component: server
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      containers:
      - name: trivy
        image: aquasec/trivy:0.48.3
        args: ["server", "--listen", "0.0.0.0:4954", "--cache-dir", "/tmp/trivy/.cache"]
        ports:
        - containerPort: 4954
          name: trivy-server
        env:
        - name: TRIVY_CACHE_DIR
          value: "/tmp/trivy/.cache"
        - name: TRIVY_TIMEOUT
          value: "10m"
        - name: TRIVY_DB_REPOSITORY
          value: "ghcr.io/aquasecurity/trivy-db"
        volumeMounts:
        - name: cache
          mountPath: /tmp/trivy/.cache
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 4954
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 4954
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          readOnlyRootFilesystem: true
      volumes:
      - name: cache
        persistentVolumeClaim:
          claimName: trivy-cache
EOF

# 5. Fix Falco deployment
echo "5. Fixing Falco deployment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: falco
  namespace: data-platform-security-scanning
  labels:
    app.kubernetes.io/name: falco
    app.kubernetes.io/component: runtime-security
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: falco
      app.kubernetes.io/component: runtime-security
  template:
    metadata:
      labels:
        app.kubernetes.io/name: falco
        app.kubernetes.io/component: runtime-security
    spec:
      serviceAccountName: falco
      containers:
      - name: falco
        image: falcosecurity/falco-no-driver:0.36.2
        args: ["/usr/bin/falco", "-K", "/var/run/secrets/kubernetes.io/serviceaccount/token", "-k", "https://kubernetes.default"]
        securityContext:
          privileged: true
        volumeMounts:
        - mountPath: /host/var/run/docker.sock
          name: docker-socket
        - mountPath: /host/dev
          name: dev-fs
          readOnly: true
        - mountPath: /host/proc
          name: proc-fs
          readOnly: true
        - mountPath: /etc/falco
          name: config-volume
        resources:
          limits:
            cpu: 1000m
            memory: 1024Mi
          requests:
            cpu: 100m
            memory: 512Mi
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: dev-fs
        hostPath:
          path: /dev
      - name: proc-fs
        hostPath:
          path: /proc
      - name: config-volume
        configMap:
          name: falco-config
          optional: true
      hostNetwork: true
      hostPID: true
EOF

# 6. Create minimal Falco config
echo "6. Creating Falco configuration..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
  namespace: data-platform-security-scanning
data:
  falco.yaml: |
    rules_file:
      - /etc/falco/falco_rules.yaml
      - /etc/falco/falco_rules.local.yaml

    json_output: true
    json_include_output_property: true

    log_stderr: true
    log_syslog: false
    log_level: info

    outputs:
      rate: 1
      max_burst: 1000

    syslog_output:
      enabled: false

    grpc:
      enabled: false

    grpc_output:
      enabled: false
EOF

echo "✅ Security scanning fixes applied!"
echo ""
echo "Checking deployment status..."
kubectl get pods -n data-platform-security-scanning
echo ""
echo "PVC status:"
kubectl get pvc -n data-platform-security-scanning

echo ""
echo "📝 Note: This is a temporary fix. The Terraform configuration should be updated to:"
echo "   1. Ensure Trivy deployment is created with count=1"
echo "   2. Use immediate binding storage class for local development"
echo "   3. Fix Falco configuration for Kind environment"
