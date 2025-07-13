package kubernetes.security

# Test: should deny root user
test_deny_root_user if {
    count(deny) > 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "securityContext": {
                            "runAsUser": 0
                        }
                    }]
                }
            }
        }
    }
}

# Test: should allow non-root user
test_allow_non_root_user if {
    count(deny) == 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "nginx:1.20",
                        "securityContext": {
                            "runAsUser": 1000
                        },
                        "resources": {
                            "limits": {
                                "memory": "128Mi",
                                "cpu": "100m"
                            }
                        }
                    }]
                }
            }
        }
    }
}

# Test: should deny missing resource limits
test_deny_missing_limits if {
    count(deny) > 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "nginx:1.20"
                    }]
                }
            }
        }
    }
}

# Test: should deny latest tag
test_deny_latest_tag if {
    count(deny) > 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "nginx:latest",
                        "resources": {
                            "limits": {
                                "memory": "128Mi",
                                "cpu": "100m"
                            }
                        }
                    }]
                }
            }
        }
    }
}
