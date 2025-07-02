output "connection" {
  description = "Cache connection details"
  value = local.is_local ? (
    length(module.kubernetes_cache) > 0 ? module.kubernetes_cache[0].connection : null
    ) : (
    length(module.aws_cache) > 0 ? module.aws_cache[0].connection : null
  )
  sensitive = true
}

output "credentials" {
  description = "Cache credentials"
  value = local.is_local ? (
    length(module.kubernetes_cache) > 0 ? module.kubernetes_cache[0].credentials : null
    ) : (
    length(module.aws_cache) > 0 ? module.aws_cache[0].credentials : null
  )
  sensitive = true
}