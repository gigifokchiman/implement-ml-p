output "connection" {
  description = "Cache connection details"
  value = {
    endpoint = aws_elasticache_replication_group.main.primary_endpoint_address
    port     = aws_elasticache_replication_group.main.port
    url      = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:${aws_elasticache_replication_group.main.port}"
  }
  sensitive = true
}

output "credentials" {
  description = "Cache credentials"
  value = {
    auth_required = aws_elasticache_replication_group.main.transit_encryption_enabled
    auth_token    = aws_elasticache_replication_group.main.auth_token
  }
  sensitive = true
}