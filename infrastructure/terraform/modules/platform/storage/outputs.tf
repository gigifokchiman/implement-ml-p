output "connection" {
  description = "Storage connection details"
  value = local.is_local ? (
    length(module.kubernetes_storage) > 0 ? module.kubernetes_storage[0].connection : null
    ) : (
    length(module.aws_storage) > 0 ? module.aws_storage[0].connection : null
  )
  sensitive = true
}

output "credentials" {
  description = "Storage credentials"
  value = local.is_local ? (
    length(module.kubernetes_storage) > 0 ? module.kubernetes_storage[0].credentials : null
    ) : (
    length(module.aws_storage) > 0 ? module.aws_storage[0].credentials : null
  )
  sensitive = true
}