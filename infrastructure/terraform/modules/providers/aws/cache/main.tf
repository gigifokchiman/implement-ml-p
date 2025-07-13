# AWS ElastiCache Redis implementation

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-group"
  })
}

resource "aws_security_group" "cache" {
  name_prefix = "${var.name}-cache-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-cache-sg"
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = var.name
  description          = "Redis cache for ${var.name}"

  node_type            = var.config.node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters = var.config.num_nodes

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.cache.id]

  at_rest_encryption_enabled = var.config.encrypted
  transit_encryption_enabled = var.config.encrypted

  tags = merge(var.tags, {
    Name = var.name
  })
}
