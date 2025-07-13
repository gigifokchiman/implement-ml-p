output "connection" {
  description = "Storage connection details"
  value = {
    endpoint = "https://s3.${var.region}.amazonaws.com"
    buckets  = { for i, bucket in aws_s3_bucket.buckets : var.config.buckets[i].name => bucket.bucket }
  }
  sensitive = true
}

output "credentials" {
  description = "Storage credentials"
  value = {
    iam_role_arn  = aws_iam_role.s3_access.arn
    iam_role_name = aws_iam_role.s3_access.name
  }
  sensitive = true
}
