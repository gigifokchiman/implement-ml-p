output "connection" {
  description = "Database connection details"
  value = local.is_local ? (
    length(module.kubernetes_database) > 0 ? module.kubernetes_database[0].connection : null
    ) : (
    length(module.aws_database) > 0 ? module.aws_database[0].connection : null
  )
  sensitive = true
}

output "credentials" {
  description = "Database credentials"
  value = local.is_local ? (
    length(module.kubernetes_database) > 0 ? module.kubernetes_database[0].credentials : null
    ) : (
    length(module.aws_database) > 0 ? module.aws_database[0].credentials : null
  )
  sensitive = true
}