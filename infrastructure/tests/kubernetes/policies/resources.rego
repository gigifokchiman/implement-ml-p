package kubernetes.resources

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Deny containers without resource requests
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests
    msg := sprintf("Container '%s' must have resource requests", [container.name])
}

# Deny containers without resource limits
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container '%s' must have resource limits", [container.name])
}

# Deny containers without CPU requests
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests.cpu
    msg := sprintf("Container '%s' must have CPU requests", [container.name])
}

# Deny containers without memory requests
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests.memory
    msg := sprintf("Container '%s' must have memory requests", [container.name])
}

# Warn if requests and limits are not equal (prevents bursting)
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.resources.requests.cpu != container.resources.limits.cpu
    msg := sprintf("Container '%s' has different CPU requests and limits (may cause throttling)", [container.name])
}

# Deny PVCs without storage class in production
deny[msg] {
    input.kind == "PersistentVolumeClaim"
    input.metadata.namespace == "ml-platform"
    not input.spec.storageClassName
    msg := "PVC must specify a storage class in production"
}

# Warn about small PVC sizes in production
warn[msg] {
    input.kind == "PersistentVolumeClaim"
    input.metadata.namespace == "ml-platform"
    size := input.spec.resources.requests.storage
    size_value := to_number(regex.find_n("\\d+", size, 1)[0])
    size_unit := regex.find_n("[A-Za-z]+", size, 1)[0]
    size_unit == "Gi"
    size_value < 10
    msg := sprintf("PVC '%s' has small storage size (%s) for production", [input.metadata.name, size])
}

# Deny deployments without replica count
deny[msg] {
    input.kind == "Deployment"
    not input.spec.replicas
    msg := "Deployment must specify replica count"
}

# Warn about single replica in production
warn[msg] {
    input.kind == "Deployment"
    input.metadata.namespace == "ml-platform"
    input.spec.replicas == 1
    msg := sprintf("Deployment '%s' has only 1 replica in production (no HA)", [input.metadata.name])
}