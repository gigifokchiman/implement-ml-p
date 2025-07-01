package kubernetes.security

# Test cases for security policies

test_deny_root_container {
    deny[_] with input as {
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

test_allow_non_root_container {
    count(deny) == 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "securityContext": {
                            "runAsUser": 1000,
                            "runAsNonRoot": true
                        }
                    }]
                }
            }
        }
    }
}

test_deny_privileged_container {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "securityContext": {
                            "privileged": true
                        }
                    }]
                }
            }
        }
    }
}

test_deny_latest_tag {
    deny[_] with input as {
        "kind": "Deployment",
        "metadata": {
            "namespace": "ml-platform"
        },
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "myapp:latest"
                    }]
                }
            }
        }
    }
}

test_allow_specific_tag {
    count(deny) == 0 with input as {
        "kind": "Deployment",
        "metadata": {
            "namespace": "ml-platform"
        },
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "myapp:v1.2.3"
                    }]
                }
            }
        }
    }
}

test_warn_missing_probes {
    warn[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "myapp:v1.0.0"
                    }]
                }
            }
        }
    }
}

test_no_warn_with_probes {
    count(warn) == 0 with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "image": "myapp:v1.0.0",
                        "livenessProbe": {
                            "httpGet": {
                                "path": "/health",
                                "port": 8080
                            }
                        },
                        "readinessProbe": {
                            "httpGet": {
                                "path": "/ready",
                                "port": 8080
                            }
                        }
                    }]
                }
            }
        }
    }
}