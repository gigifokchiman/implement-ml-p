package kubernetes.security

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Deny containers running as root
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.runAsUser == 0
    msg := sprintf("Container '%s' is running as root (UID 0)", [container.name])
}

# Deny containers without runAsNonRoot
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container '%s' should set runAsNonRoot: true", [container.name])
}

# Deny containers with privileged access
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Container '%s' should not run in privileged mode", [container.name])
}

# Deny containers without readOnlyRootFilesystem
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container '%s' should set readOnlyRootFilesystem: true", [container.name])
}

# Deny host network usage
deny[msg] {
    input.kind == "Pod"
    input.spec.hostNetwork == true
    msg := "Pods should not use host network"
}

# Deny host PID usage
deny[msg] {
    input.kind == "Pod"
    input.spec.hostPID == true
    msg := "Pods should not use host PID namespace"
}

# Require security context at pod level
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext
    msg := "Pod should have a security context defined"
}

# Deny latest image tags in production
deny[msg] {
    input.kind == "Deployment"
    input.metadata.namespace == "ml-platform"
    container := input.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%s' should not use ':latest' tag in production", [container.name])
}

# Deny containers without health checks
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container '%s' should have a liveness probe", [container.name])
}

warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container '%s' should have a readiness probe", [container.name])
}