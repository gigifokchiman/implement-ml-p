package kubernetes.security

# Deny containers that run as root user
deny contains msg if {
    input.kind == "Deployment"
    input.spec.template.spec.containers[_].securityContext.runAsUser == 0
    msg := "Container should not run as root user"
}

# Deny containers without resource limits
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container '%s' should have resource limits", [container.name])
}

# Deny containers using latest tag
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%s' should not use 'latest' tag", [container.name])
}
