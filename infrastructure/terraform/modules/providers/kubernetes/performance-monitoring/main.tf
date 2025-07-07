# Kubernetes Performance Monitoring Implementation
# Uses Jaeger for distributed tracing, OpenTelemetry for metrics, and ELK stack for logs

# Sanitize tags for Kubernetes compatibility
locals {
  k8s_tags = {
    for key, value in var.tags : key => replace(replace(value, "/", "-"), ":", "-")
  }
}

# Namespace for performance monitoring
resource "kubernetes_namespace" "performance_monitoring" {
  metadata {
    name = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"             = "performance-monitoring"
      "app.kubernetes.io/component"        = "observability"
      "workload-type"                      = "observability"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    })
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

# Jaeger for Distributed Tracing
resource "kubernetes_deployment" "jaeger" {
  count = var.config.enable_distributed_trace ? 1 : 0

  metadata {
    name      = "jaeger"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "jaeger"
      "app.kubernetes.io/component" = "tracing"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "jaeger"
        "app.kubernetes.io/component" = "tracing"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "jaeger"
          "app.kubernetes.io/component" = "tracing"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }

        container {
          name  = "jaeger"
          image = "jaegertracing/all-in-one:1.50"

          env {
            name  = "COLLECTOR_OTLP_ENABLED"
            value = "true"
          }

          env {
            name  = "SPAN_STORAGE_TYPE"
            value = "badger"
          }

          env {
            name  = "BADGER_EPHEMERAL"
            value = "false"
          }

          env {
            name  = "BADGER_DIRECTORY_VALUE"
            value = "/tmp/badger/data"
          }

          env {
            name  = "BADGER_DIRECTORY_KEY"
            value = "/tmp/badger/key"
          }

          port {
            container_port = 16686
            name           = "ui"
          }

          port {
            container_port = 14268
            name           = "jaeger-thrift"
          }

          port {
            container_port = 4317
            name           = "otlp-grpc"
          }

          port {
            container_port = 4318
            name           = "otlp-http"
          }

          volume_mount {
            name       = "jaeger-storage"
            mount_path = "/tmp/badger"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = false
          }
        }

        volume {
          name = "jaeger-storage"
          persistent_volume_claim {
            claim_name = "jaeger-storage"
          }
        }
      }
    }
  }
}

# Jaeger storage PVC
resource "kubernetes_persistent_volume_claim" "jaeger_storage" {
  count = var.config.enable_distributed_trace ? 1 : 0

  metadata {
    name      = "jaeger-storage"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "jaeger"
      "app.kubernetes.io/component" = "storage"
    })
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = var.config.trace_storage_size
      }
    }
  }
}

# Jaeger service
resource "kubernetes_service" "jaeger" {
  count = var.config.enable_distributed_trace ? 1 : 0

  metadata {
    name      = "jaeger"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "jaeger"
      "app.kubernetes.io/component" = "tracing"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "jaeger"
      "app.kubernetes.io/component" = "tracing"
    }

    port {
      name        = "ui"
      port        = 16686
      target_port = 16686
    }

    port {
      name        = "jaeger-thrift"
      port        = 14268
      target_port = 14268
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }

    type = "ClusterIP"
  }
}

# Fluent Bit for Audit Log Processing (EFK Stack)
resource "kubernetes_config_map" "fluent_bit_config" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "fluent-bit-config"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "fluent-bit"
      "app.kubernetes.io/component" = "config"
    })
  }

  data = {
    "fluent-bit.conf" = <<-EOT
      [SERVICE]
          Flush         1
          Log_Level     info
          Daemon        off
          Parsers_File  parsers.conf
          HTTP_Server   On
          HTTP_Listen   0.0.0.0
          HTTP_Port     2020

      [INPUT]
          Name              tail
          Path              /var/log/audit.log
          Parser            k8s_audit
          Tag               kubernetes.audit
          Refresh_Interval  5
          Mem_Buf_Limit     50MB
          Skip_Long_Lines   On

      [FILTER]
          Name                kubernetes
          Match               kubernetes.*
          Kube_URL            https://kubernetes.default.svc.cluster.local:443
          Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
          Merge_Log           On
          K8S-Logging.Parser  On
          K8S-Logging.Exclude Off

      [FILTER]
          Name    record_modifier
          Match   kubernetes.audit
          Record  log_source audit
          Record  environment ${var.environment}

      [OUTPUT]
          Name  es
          Match kubernetes.audit
          Host  elasticsearch.${var.name}.svc.cluster.local
          Port  9200
          Index k8s-audit-logs
          Type  _doc
          Logstash_Format On
          Logstash_Prefix k8s-audit
          Time_Key @timestamp
          Time_Key_Format %Y-%m-%dT%H:%M:%S.%L%z
          Include_Tag_Key On
          Tag_Key tag
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name        k8s_audit
          Format      json
          Time_Key    stageTimestamp
          Time_Format %Y-%m-%dT%H:%M:%S.%L%z
          Time_Keep   On
    EOT
  }
}

resource "kubernetes_daemonset" "fluent_bit" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "fluent-bit"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "fluent-bit"
      "app.kubernetes.io/component" = "log-processor"
    })
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "fluent-bit"
        "app.kubernetes.io/component" = "log-processor"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "fluent-bit"
          "app.kubernetes.io/component" = "log-processor"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fluent_bit[0].metadata[0].name

        # Only run on control plane where audit logs are generated
        node_selector = {
          "node-role.kubernetes.io/control-plane" = ""
        }

        toleration {
          key    = "node-role.kubernetes.io/control-plane"
          effect = "NoSchedule"
        }

        container {
          name  = "fluent-bit"
          image = "fluent/fluent-bit:2.2.0"

          port {
            container_port = 2020
            name           = "http"
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc"
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "50Mi"
            }
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.fluent_bit_config[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account" "fluent_bit" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "fluent-bit"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "fluent-bit"
      "app.kubernetes.io/component" = "log-processor"
    })
  }
}

resource "kubernetes_cluster_role" "fluent_bit" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name = "fluent-bit"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "fluent-bit"
      "app.kubernetes.io/component" = "log-processor"
    })
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "fluent_bit" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name = "fluent-bit"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "fluent-bit"
      "app.kubernetes.io/component" = "log-processor"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluent_bit[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluent_bit[0].metadata[0].name
    namespace = var.name
  }
}

# OpenTelemetry Collector
resource "kubernetes_deployment" "otel_collector" {
  count = var.config.enable_custom_metrics ? 1 : 0

  metadata {
    name      = "otel-collector"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "metrics"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "otel-collector"
        "app.kubernetes.io/component" = "metrics"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "otel-collector"
          "app.kubernetes.io/component" = "metrics"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.otel_collector[0].metadata[0].name

        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }

        container {
          name  = "otel-collector"
          image = "otel/opentelemetry-collector-contrib:0.89.0"

          args = ["--config=/etc/otel-collector-config.yaml"]

          port {
            container_port = 4317
            name           = "otlp-grpc"
          }

          port {
            container_port = 4318
            name           = "otlp-http"
          }

          port {
            container_port = 8888
            name           = "metrics"
          }

          port {
            container_port = 8889
            name           = "prometheus"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/otel-collector-config.yaml"
            sub_path   = "config.yaml"
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.otel_collector_config[0].metadata[0].name
          }
        }
      }
    }
  }
}

# OpenTelemetry Collector configuration
resource "kubernetes_config_map" "otel_collector_config" {
  count = var.config.enable_custom_metrics ? 1 : 0

  metadata {
    name      = "otel-collector-config"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "config"
    })
  }

  data = {
    "config.yaml" = yamlencode({
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
        prometheus = {
          config = {
            scrape_configs = [
              {
                job_name = "kubernetes-pods"
                kubernetes_sd_configs = [{
                  role = "pod"
                }]
                relabel_configs = [
                  {
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                    action        = "keep"
                    regex         = "true"
                  }
                ]
              }
            ]
          }
        }
      }

      processors = {
        batch = {}
        memory_limiter = {
          check_interval = "1s"
          limit_mib      = 512
        }
        resource = {
          attributes = [
            {
              key    = "environment"
              value  = var.environment
              action = "upsert"
            }
          ]
        }
      }

      exporters = {
        prometheus = {
          endpoint = "0.0.0.0:8889"
        }
        otlp = var.config.enable_distributed_trace ? {
          endpoint = "jaeger:4317"
          tls = {
            insecure = true
          }
        } : null
        logging = {
          loglevel = "debug"
        }
      }

      service = {
        pipelines = {
          metrics = {
            receivers  = ["otlp", "prometheus"]
            processors = ["memory_limiter", "batch", "resource"]
            exporters  = ["prometheus", "logging"]
          }
          traces = var.config.enable_distributed_trace ? {
            receivers  = ["otlp"]
            processors = ["memory_limiter", "batch", "resource"]
            exporters  = ["otlp", "logging"]
          } : null
        }
      }
    })
  }
}

# Service account for OpenTelemetry Collector
resource "kubernetes_service_account" "otel_collector" {
  count = var.config.enable_custom_metrics ? 1 : 0

  metadata {
    name      = "otel-collector"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "metrics"
    })
  }
}

# Cluster role for OpenTelemetry Collector
resource "kubernetes_cluster_role" "otel_collector" {
  count = var.config.enable_custom_metrics ? 1 : 0

  metadata {
    name = "otel-collector"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "metrics"
    })
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }
}

# Cluster role binding for OpenTelemetry Collector
resource "kubernetes_cluster_role_binding" "otel_collector" {
  count = var.config.enable_custom_metrics ? 1 : 0

  metadata {
    name = "otel-collector"
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "metrics"
    })
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.otel_collector[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.otel_collector[0].metadata[0].name
    namespace = var.name
  }
}

# OpenTelemetry Collector service
resource "kubernetes_service" "otel_collector" {
  count = var.config.enable_custom_metrics ? 1 : 0

  metadata {
    name      = "otel-collector"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "metrics"
    })
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8889"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "otel-collector"
      "app.kubernetes.io/component" = "metrics"
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }

    port {
      name        = "metrics"
      port        = 8888
      target_port = 8888
    }

    port {
      name        = "prometheus"
      port        = 8889
      target_port = 8889
    }

    type = "ClusterIP"
  }
}

# Elasticsearch for log aggregation
resource "kubernetes_deployment" "elasticsearch" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "elasticsearch"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "elasticsearch"
      "app.kubernetes.io/component" = "search"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "elasticsearch"
        "app.kubernetes.io/component" = "search"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "elasticsearch"
          "app.kubernetes.io/component" = "search"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "elasticsearch"
          image = "docker.elastic.co/elasticsearch/elasticsearch:8.11.1"

          env {
            name  = "discovery.type"
            value = "single-node"
          }

          env {
            name  = "xpack.security.enabled"
            value = "false"
          }

          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms512m -Xmx512m"
          }

          port {
            container_port = 9200
            name           = "http"
          }

          port {
            container_port = 9300
            name           = "transport"
          }

          volume_mount {
            name       = "elasticsearch-storage"
            mount_path = "/usr/share/elasticsearch/data"
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = false
          }
        }

        volume {
          name = "elasticsearch-storage"
          persistent_volume_claim {
            claim_name = "elasticsearch-storage"
          }
        }
      }
    }
  }
}

# Elasticsearch storage PVC
resource "kubernetes_persistent_volume_claim" "elasticsearch_storage" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "elasticsearch-storage"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "elasticsearch"
      "app.kubernetes.io/component" = "storage"
    })
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.config.log_storage_size
      }
    }
  }
}

# Elasticsearch service
resource "kubernetes_service" "elasticsearch" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "elasticsearch"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "elasticsearch"
      "app.kubernetes.io/component" = "search"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "elasticsearch"
      "app.kubernetes.io/component" = "search"
    }

    port {
      name        = "http"
      port        = 9200
      target_port = 9200
    }

    port {
      name        = "transport"
      port        = 9300
      target_port = 9300
    }

    type = "ClusterIP"
  }
}

# Kibana for log visualization
resource "kubernetes_deployment" "kibana" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "kibana"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kibana"
      "app.kubernetes.io/component" = "visualization"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "kibana"
        "app.kubernetes.io/component" = "visualization"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "kibana"
          "app.kubernetes.io/component" = "visualization"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "kibana"
          image = "docker.elastic.co/kibana/kibana:8.11.1"

          env {
            name  = "ELASTICSEARCH_HOSTS"
            value = "http://elasticsearch:9200"
          }

          port {
            container_port = 5601
            name           = "http"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = false
          }
        }
      }
    }
  }
}

# Kibana service
resource "kubernetes_service" "kibana" {
  count = var.config.enable_log_aggregation ? 1 : 0

  metadata {
    name      = "kibana"
    namespace = var.name
    labels = merge(local.k8s_tags, {
      "app.kubernetes.io/name"      = "kibana"
      "app.kubernetes.io/component" = "visualization"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "kibana"
      "app.kubernetes.io/component" = "visualization"
    }

    port {
      name        = "http"
      port        = 5601
      target_port = 5601
    }

    type = "ClusterIP"
  }
}