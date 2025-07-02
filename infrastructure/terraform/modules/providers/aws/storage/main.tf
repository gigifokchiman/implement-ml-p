# AWS S3 implementation

# Create S3 buckets
resource "aws_s3_bucket" "buckets" {
  count  = length(var.config.buckets)
  bucket = "${var.name}-${var.config.buckets[count.index].name}"

  tags = merge(var.tags, {
    Name = "${var.name}-${var.config.buckets[count.index].name}"
  })
}

# Configure versioning
resource "aws_s3_bucket_versioning" "buckets" {
  count  = var.config.versioning_enabled ? length(var.config.buckets) : 0
  bucket = aws_s3_bucket.buckets[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Configure encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  count  = var.config.encryption_enabled ? length(var.config.buckets) : 0
  bucket = aws_s3_bucket.buckets[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Configure lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  count  = var.config.lifecycle_enabled ? length(var.config.buckets) : 0
  bucket = aws_s3_bucket.buckets[count.index].id

  rule {
    id     = "ml_artifacts_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Configure public access block
resource "aws_s3_bucket_public_access_block" "buckets" {
  count  = length(var.config.buckets)
  bucket = aws_s3_bucket.buckets[count.index].id

  block_public_acls       = !var.config.buckets[count.index].public
  block_public_policy     = !var.config.buckets[count.index].public
  ignore_public_acls      = !var.config.buckets[count.index].public
  restrict_public_buckets = !var.config.buckets[count.index].public
}

# IAM role for S3 access
resource "aws_iam_role" "s3_access" {
  name = "${var.name}-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.name}-s3-access-policy"
  role = aws_iam_role.s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          [for bucket in aws_s3_bucket.buckets : bucket.arn],
          [for bucket in aws_s3_bucket.buckets : "${bucket.arn}/*"]
        )
      }
    ]
  })
}