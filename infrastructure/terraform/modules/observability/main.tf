# OpenTelemetry Collector for distributed tracing
resource "kubernetes_manifest" "otel_collector" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"

    metadata = {
      name      = "otel-collector"
      namespace = var.namespace
    }

    spec = {
      mode     = "deployment"
      replicas = 2

      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
              }
            }
          }
          jaeger = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:14250"
              }
              thrift_http = {
                endpoint = "0.0.0.0:14268"
              }
              thrift_compact = {
                endpoint = "0.0.0.0:6831"
              }
            }
          }
          zipkin = {
            endpoint = "0.0.0.0:9411"
          }
        }

        processors = {
          batch = {}

          resource = {
            attributes = [
              {
                key    = "service.namespace"
                value  = var.namespace
                action = "upsert"
              },
              {
                key    = "deployment.environment"
                value  = var.environment
                action = "upsert"
              }
            ]
          }

          probabilistic_sampler = {
            sampling_percentage = var.environment == "local" ? 100 : 10
          }
        }

        exporters = {
          jaeger = {
            endpoint = var.environment == "local" ? "jaeger-all-in-one.jaeger-system.svc.cluster.local:14250" : "jaeger-collector.jaeger-system.svc.cluster.local:14250"
            tls = {
              insecure = true
            }
          }

          prometheus = {
            endpoint = "0.0.0.0:8889"
            const_labels = {
              environment = var.environment
              service     = "otel-collector"
            }
          }

          logging = {
            loglevel = var.environment == "local" ? "debug" : "info"
          }
        }

        extensions = {
          health_check = {}
          pprof        = {}
          zpages       = {}
        }

        service = {
          extensions = ["health_check", "pprof", "zpages"]

          pipelines = {
            traces = {
              receivers  = ["otlp", "jaeger", "zipkin"]
              processors = ["resource", "probabilistic_sampler", "batch"]
              exporters  = ["jaeger", "logging"]
            }

            metrics = {
              receivers  = ["otlp"]
              processors = ["resource", "batch"]
              exporters  = ["prometheus", "logging"]
            }
          }
        }
      }

      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      podSecurityContext = {
        runAsNonRoot = true
        runAsUser    = 65534
        fsGroup      = 65534
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }

      securityContext = {
        allowPrivilegeEscalation = false
        capabilities = {
          drop = ["ALL"]
        }
        readOnlyRootFilesystem = true
      }
    }
  }
}

# Service Monitor for OpenTelemetry Collector
resource "kubernetes_manifest" "otel_collector_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "otel-collector"
      namespace = var.namespace
      labels = {
        app = "otel-collector"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "opentelemetry-collector"
        }
      }

      endpoints = [
        {
          port     = "prometheus"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}

# Tracing configuration for ML Platform applications
resource "kubernetes_config_map" "tracing_config" {
  metadata {
    name      = "tracing-config"
    namespace = var.namespace
  }

  data = {
    "tracing.yaml" = yamlencode({
      tracing = {
        enabled = true

        jaeger = {
          agent_host         = "otel-collector.${var.namespace}.svc.cluster.local"
          agent_port         = 6831
          collector_endpoint = "http://otel-collector.${var.namespace}.svc.cluster.local:14268/api/traces"
        }

        otlp = {
          endpoint = "http://otel-collector.${var.namespace}.svc.cluster.local:4318"
          headers = {
            "Content-Type" = "application/json"
          }
        }

        sampling = {
          rate                  = var.environment == "local" ? 1.0 : 0.1
          max_traces_per_second = 1000
        }

        tags = {
          service_name    = "ml-platform"
          service_version = "1.0.0"
          environment     = var.environment
          namespace       = var.namespace
        }
      }
    })

    "prometheus-tracing-rules.yaml" = yamlencode({
      groups = [
        {
          name     = "tracing.rules"
          interval = "30s"
          rules = [
            {
              alert = "HighTraceLatency"
              expr  = "histogram_quantile(0.95, sum(rate(traces_latency_bucket[5m])) by (le, service_name)) > 1"
              for   = "5m"
              labels = {
                severity  = "warning"
                component = "tracing"
              }
              annotations = {
                summary     = "High trace latency detected"
                description = "Service {{ $labels.service_name }} has 95th percentile latency above 1 second"
              }
            },
            {
              alert = "HighErrorRate"
              expr  = "sum(rate(traces_total{status_code!=\"OK\"}[5m])) by (service_name) / sum(rate(traces_total[5m])) by (service_name) > 0.05"
              for   = "2m"
              labels = {
                severity  = "critical"
                component = "tracing"
              }
              annotations = {
                summary     = "High error rate in traces"
                description = "Service {{ $labels.service_name }} has error rate above 5%"
              }
            },
            {
              alert = "TracingPipelineDown"
              expr  = "up{job=\"otel-collector\"} == 0"
              for   = "1m"
              labels = {
                severity  = "critical"
                component = "tracing"
              }
              annotations = {
                summary     = "Tracing pipeline is down"
                description = "OpenTelemetry Collector is not responding"
              }
            }
          ]
        }
      ]
    })
  }
}

# Grafana dashboard for distributed tracing
resource "kubernetes_config_map" "tracing_dashboard" {
  metadata {
    name      = "tracing-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "tracing-overview.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Distributed Tracing Overview"
        tags     = ["tracing", "jaeger", "observability"]
        timezone = "browser"
        panels = [
          {
            id    = 1
            title = "Request Rate"
            type  = "stat"
            targets = [
              {
                expr         = "sum(rate(traces_total[5m]))"
                legendFormat = "Requests/sec"
              }
            ]
            fieldConfig = {
              defaults = {
                unit = "reqps"
              }
            }
            gridPos = {
              h = 8
              w = 6
              x = 0
              y = 0
            }
          },
          {
            id    = 2
            title = "Error Rate"
            type  = "stat"
            targets = [
              {
                expr         = "sum(rate(traces_total{status_code!=\"OK\"}[5m])) / sum(rate(traces_total[5m])) * 100"
                legendFormat = "Error %"
              }
            ]
            fieldConfig = {
              defaults = {
                unit = "percent"
                thresholds = {
                  steps = [
                    { color = "green", value = null },
                    { color = "yellow", value = 1 },
                    { color = "red", value = 5 }
                  ]
                }
              }
            }
            gridPos = {
              h = 8
              w = 6
              x = 6
              y = 0
            }
          },
          {
            id    = 3
            title = "P95 Latency"
            type  = "stat"
            targets = [
              {
                expr         = "histogram_quantile(0.95, sum(rate(traces_latency_bucket[5m])) by (le))"
                legendFormat = "P95 Latency"
              }
            ]
            fieldConfig = {
              defaults = {
                unit = "s"
              }
            }
            gridPos = {
              h = 8
              w = 6
              x = 12
              y = 0
            }
          },
          {
            id    = 4
            title = "Service Map"
            type  = "nodeGraph"
            targets = [
              {
                expr         = "sum by (source_service, target_service) (rate(traces_service_graph_request_total[5m]))"
                legendFormat = "{{source_service}} -> {{target_service}}"
              }
            ]
            gridPos = {
              h = 16
              w = 24
              x = 0
              y = 8
            }
          }
        ]
        time = {
          from = "now-1h"
          to   = "now"
        }
        refresh = "30s"
      }
    })
  }
}

# Auto-instrumentation for applications
resource "kubernetes_manifest" "auto_instrumentation" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "Instrumentation"

    metadata = {
      name      = "ml-platform-auto-instrumentation"
      namespace = var.namespace
    }

    spec = {
      exporter = {
        endpoint = "http://otel-collector.${var.namespace}.svc.cluster.local:4318"
      }

      propagators = [
        "tracecontext",
        "baggage",
        "b3"
      ]

      sampler = {
        type     = "parentbased_traceidratio"
        argument = var.environment == "local" ? "1.0" : "0.1"
      }

      python = {
        image = "ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.40b0"
      }

      nodejs = {
        image = "ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.43.0"
      }

      java = {
        image = "ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.31.0"
      }

      dotnet = {
        image = "ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:0.7.0"
      }
    }
  }
}

# Network policy for tracing components
resource "kubernetes_manifest" "tracing_network_policy" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"

    metadata = {
      name      = "tracing-network-policy"
      namespace = var.namespace
    }

    spec = {
      podSelector = {
        matchLabels = {
          "app.kubernetes.io/name" = "opentelemetry-collector"
        }
      }

      policyTypes = ["Ingress", "Egress"]

      ingress = [
        {
          from = [
            {
              podSelector = {}
            }
          ]
          ports = [
            { protocol = "TCP", port = 4317 },  # OTLP gRPC
            { protocol = "TCP", port = 4318 },  # OTLP HTTP
            { protocol = "TCP", port = 14250 }, # Jaeger gRPC
            { protocol = "TCP", port = 14268 }, # Jaeger HTTP
            { protocol = "TCP", port = 6831 },  # Jaeger UDP
            { protocol = "TCP", port = 9411 },  # Zipkin
            { protocol = "TCP", port = 8889 }   # Prometheus metrics
          ]
        }
      ]

      egress = [
        {
          to = []
          ports = [
            { protocol = "UDP", port = 53 } # DNS
          ]
        },
        {
          to = [
            {
              namespaceSelector = {
                matchLabels = {
                  name = "jaeger-system"
                }
              }
            }
          ]
          ports = [
            { protocol = "TCP", port = 14250 } # Jaeger collector
          ]
        }
      ]
    }
  }
}