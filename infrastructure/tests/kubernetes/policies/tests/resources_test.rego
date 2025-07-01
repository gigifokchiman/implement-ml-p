package kubernetes.resources

# Test cases for resource policies

test_allow_deployment_with_resources {
    count(deny) == 0 with input as {
        "kind": "Deployment",
        "metadata": {
            "name": "test-app",
            "namespace": "ml-platform"
        },
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "resources": {
                            "requests": {
                                "cpu": "100m",
                                "memory": "128Mi"
                            },
                            "limits": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            }
                        }
                    }]
                }
            }
        }
    }
}

test_deny_deployment_without_requests {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "resources": {
                            "limits": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            }
                        }
                    }]
                }
            }
        }
    }
}

test_deny_deployment_without_limits {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "resources": {
                            "requests": {
                                "cpu": "100m",
                                "memory": "128Mi"
                            }
                        }
                    }]
                }
            }
        }
    }
}

test_deny_deployment_without_cpu_requests {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "resources": {
                            "requests": {
                                "memory": "128Mi"
                            },
                            "limits": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            }
                        }
                    }]
                }
            }
        }
    }
}

test_deny_deployment_without_memory_requests {
    deny[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "resources": {
                            "requests": {
                                "cpu": "100m"
                            },
                            "limits": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            }
                        }
                    }]
                }
            }
        }
    }
}

test_warn_different_cpu_requests_limits {
    warn[_] with input as {
        "kind": "Deployment",
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app",
                        "resources": {
                            "requests": {
                                "cpu": "100m",
                                "memory": "128Mi"
                            },
                            "limits": {
                                "cpu": "200m",  # Different from request
                                "memory": "128Mi"
                            }
                        }
                    }]
                }
            }
        }
    }
}

test_deny_pvc_without_storage_class {
    deny[_] with input as {
        "kind": "PersistentVolumeClaim",
        "metadata": {
            "namespace": "ml-platform"
        },
        "spec": {
            "resources": {
                "requests": {
                    "storage": "10Gi"
                }
            }
        }
    }
}

test_allow_pvc_with_storage_class {
    count(deny) == 0 with input as {
        "kind": "PersistentVolumeClaim",
        "metadata": {
            "namespace": "ml-platform"
        },
        "spec": {
            "storageClassName": "standard",
            "resources": {
                "requests": {
                    "storage": "10Gi"
                }
            }
        }
    }
}

test_warn_small_pvc_in_production {
    warn[_] with input as {
        "kind": "PersistentVolumeClaim",
        "metadata": {
            "name": "small-pvc",
            "namespace": "ml-platform"
        },
        "spec": {
            "storageClassName": "standard",
            "resources": {
                "requests": {
                    "storage": "5Gi"  # Small size
                }
            }
        }
    }
}

test_deny_deployment_without_replicas {
    deny[_] with input as {
        "kind": "Deployment",
        "metadata": {
            "name": "test-app"
        },
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app"
                    }]
                }
            }
        }
    }
}

test_warn_single_replica_in_production {
    warn[_] with input as {
        "kind": "Deployment",
        "metadata": {
            "name": "single-replica-app",
            "namespace": "ml-platform"
        },
        "spec": {
            "replicas": 1,
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app"
                    }]
                }
            }
        }
    }
}

test_allow_multiple_replicas_in_production {
    count(warn) == 0 with input as {
        "kind": "Deployment",
        "metadata": {
            "name": "ha-app",
            "namespace": "ml-platform"
        },
        "spec": {
            "replicas": 3,
            "template": {
                "spec": {
                    "containers": [{
                        "name": "app"
                    }]
                }
            }
        }
    }
}