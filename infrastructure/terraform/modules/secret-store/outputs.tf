# Secret Store Module Outputs

output "secret_store_namespace" {
  description = "Name of the secret store namespace"
  value       = kubernetes_namespace.secret_store.metadata[0].name
}

output "platform_secrets_name" {
  description = "Name of the platform secrets"
  value       = kubernetes_secret.platform_secrets.metadata[0].name
}

output "secret_reader_service_account" {
  description = "Name of the secret reader service account"
  value       = kubernetes_service_account.secret_reader.metadata[0].name
}

# Secure secret retrieval commands (no plaintext exposure)
output "secret_retrieval_commands" {
  description = "Commands to securely retrieve secrets"
  value = {
    argocd_password   = "kubectl get secret platform-secrets -n secret-store -o jsonpath='{.data.argocd_admin_password}' | base64 -d"
    grafana_password  = "kubectl get secret platform-secrets -n secret-store -o jsonpath='{.data.grafana_admin_password}' | base64 -d"
    postgres_password = "kubectl get secret platform-secrets -n secret-store -o jsonpath='{.data.postgres_admin_password}' | base64 -d"
    minio_credentials = "kubectl get secret platform-secrets -n secret-store -o jsonpath='{.data.minio_access_key}' | base64 -d && echo ':' && kubectl get secret platform-secrets -n secret-store -o jsonpath='{.data.minio_secret_key}' | base64 -d"
  }
}