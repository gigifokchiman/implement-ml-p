# Cluster Autoscaler IAM role
resource "aws_iam_role" "cluster_autoscaler_role" {
  count = var.environment != "local" ? 1 : 0

  name = "${var.name_prefix}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Cluster Autoscaler IAM policy
resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  count = var.environment != "local" ? 1 : 0

  name = "${var.name_prefix}-cluster-autoscaler-policy"
  role = aws_iam_role.cluster_autoscaler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes"
        ]
        Resource = "*"
      }
    ]
  })
}

# Node group configuration for autoscaling
resource "aws_eks_node_group" "ml_workloads" {
  count = var.environment != "local" ? 1 : 0

  cluster_name    = var.cluster_name
  node_group_name = "${var.name_prefix}-ml-workloads"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  capacity_type  = "SPOT"
  instance_types = ["m5.large", "m5.xlarge", "m5.2xlarge"]

  scaling_config {
    desired_size = 1
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "node-type"     = "ml-workloads"
    "capacity-type" = "spot"
  }

  taint {
    key    = "ml-workloads"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.tags, {
    "k8s.io/cluster-autoscaler/enabled"                           = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"               = "owned"
    "k8s.io/cluster-autoscaler/node-template/label/node-type"     = "ml-workloads"
    "k8s.io/cluster-autoscaler/node-template/label/capacity-type" = "spot"
    "k8s.io/cluster-autoscaler/node-template/taint/ml-workloads"  = "true:NoSchedule"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Node group for general workloads
resource "aws_eks_node_group" "general" {
  count = var.environment != "local" ? 1 : 0

  cluster_name    = var.cluster_name
  node_group_name = "${var.name_prefix}-general"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.medium", "t3.large"]

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "node-type"     = "general"
    "capacity-type" = "on-demand"
  }

  tags = merge(var.tags, {
    "k8s.io/cluster-autoscaler/enabled"                           = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"               = "owned"
    "k8s.io/cluster-autoscaler/node-template/label/node-type"     = "general"
    "k8s.io/cluster-autoscaler/node-template/label/capacity-type" = "on-demand"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Horizontal Pod Autoscaler policies
resource "kubernetes_manifest" "hpa_backend" {
  manifest = {
    apiVersion = "autoscaling/v2"
    kind       = "HorizontalPodAutoscaler"

    metadata = {
      name      = "ml-platform-backend-hpa"
      namespace = var.namespace
    }

    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "ml-platform-backend"
      }

      minReplicas = 2
      maxReplicas = 20

      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type               = "Utilization"
              averageUtilization = 70
            }
          }
        },
        {
          type = "Resource"
          resource = {
            name = "memory"
            target = {
              type               = "Utilization"
              averageUtilization = 80
            }
          }
        }
      ]

      behavior = {
        scaleDown = {
          stabilizationWindowSeconds = 300
          policies = [
            {
              type          = "Percent"
              value         = 10
              periodSeconds = 60
            }
          ]
        }
        scaleUp = {
          stabilizationWindowSeconds = 0
          policies = [
            {
              type          = "Percent"
              value         = 100
              periodSeconds = 15
            },
            {
              type          = "Pods"
              value         = 4
              periodSeconds = 15
            }
          ]
          selectPolicy = "Max"
        }
      }
    }
  }
}

# Pod Disruption Budget for backend
resource "kubernetes_manifest" "pdb_backend" {
  manifest = {
    apiVersion = "policy/v1"
    kind       = "PodDisruptionBudget"

    metadata = {
      name      = "ml-platform-backend-pdb"
      namespace = var.namespace
    }

    spec = {
      minAvailable = 1
      selector = {
        matchLabels = {
          app = "ml-platform-backend"
        }
      }
    }
  }
}

# Cost optimization: Priority classes
resource "kubernetes_manifest" "priority_class_critical" {
  manifest = {
    apiVersion = "scheduling.k8s.io/v1"
    kind       = "PriorityClass"

    metadata = {
      name = "ml-platform-critical"
    }

    value         = 1000
    globalDefault = false
    description   = "Critical ML Platform workloads"
  }
}

resource "kubernetes_manifest" "priority_class_normal" {
  manifest = {
    apiVersion = "scheduling.k8s.io/v1"
    kind       = "PriorityClass"

    metadata = {
      name = "ml-platform-normal"
    }

    value         = 100
    globalDefault = false
    description   = "Normal ML Platform workloads"
  }
}

resource "kubernetes_manifest" "priority_class_low" {
  manifest = {
    apiVersion = "scheduling.k8s.io/v1"
    kind       = "PriorityClass"

    metadata = {
      name = "ml-platform-low"
    }

    value         = 10
    globalDefault = false
    description   = "Low priority ML Platform workloads (batch jobs, training)"
  }
}