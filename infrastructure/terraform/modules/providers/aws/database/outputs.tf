output "connection" {
  description = "Database connection details"
  value = {
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    username = aws_db_instance.main.username
    database = aws_db_instance.main.db_name
    url      = "postgresql://${aws_db_instance.main.username}@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  }
  sensitive = true
}

output "credentials" {
  description = "Database credentials"
  value = {
    username            = aws_db_instance.main.username
    password_secret_arn = aws_secretsmanager_secret.database.arn
  }
  sensitive = true
}