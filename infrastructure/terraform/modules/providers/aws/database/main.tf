# AWS RDS implementation

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-group"
  })
}

resource "aws_security_group" "database" {
  name_prefix = "${var.name}-db-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
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
    Name = "${var.name}-database-sg"
  })
}

resource "random_password" "database" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.name}-database-password"
  description             = "Database password for ${var.name}"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = var.config.username
    password = random_password.database.result
  })
}

resource "aws_db_instance" "main" {
  identifier = var.name

  engine         = var.config.engine
  engine_version = var.config.version
  instance_class = var.config.instance_class

  allocated_storage     = var.config.storage_size
  max_allocated_storage = var.config.storage_size * 2

  db_name  = var.config.database_name
  username = var.config.username
  password = random_password.database.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  multi_az                = var.config.multi_az
  storage_encrypted       = var.config.encrypted
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = var.deletion_protection
  skip_final_snapshot = !var.deletion_protection

  tags = merge(var.tags, {
    Name = var.name
  })
}