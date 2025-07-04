output "scanner_endpoints" {
  description = "Security scanner service endpoints"
  value = {
    trivy_server = var.config.enable_image_scanning ? "http://trivy-server.${var.name}.svc.cluster.local:4954" : null
    falco_grpc   = var.config.enable_runtime_scanning ? "http://falco.${var.name}.svc.cluster.local:5060" : null
    falco_http   = var.config.enable_runtime_scanning ? "http://falco.${var.name}.svc.cluster.local:8765" : null
  }
}

output "vulnerability_database" {
  description = "Vulnerability database information"
  value = {
    enabled    = var.config.enable_vulnerability_db
    cache_size = var.config.enable_vulnerability_db ? kubernetes_persistent_volume_claim.trivy_cache[0].spec[0].resources[0].requests.storage : null
    namespace  = var.name
  }
}

output "scan_reports_location" {
  description = "Location where scan reports are stored"
  value       = "kubectl logs -n ${var.name} -l app.kubernetes.io/component=scanner"
}

output "namespace" {
  description = "Security scanning namespace"
  value       = var.name
}

output "useful_commands" {
  description = "Useful commands for security scanning operations"
  value = [
    "# Port forward to Trivy server",
    var.config.enable_image_scanning ? "kubectl port-forward -n ${var.name} svc/trivy-server 4954:4954" : null,
    "# Port forward to Falco",
    var.config.enable_runtime_scanning ? "kubectl port-forward -n ${var.name} svc/falco 8765:8765" : null,
    "# Check scan job logs",
    "kubectl logs -n ${var.name} -l app.kubernetes.io/component=scanner",
    "# Manual image scan",
    var.config.enable_image_scanning ? "kubectl run -n ${var.name} --rm -i --tty trivy-manual --image=aquasec/trivy:0.48.3 --restart=Never -- trivy image --server http://trivy-server:4954 <image-name>" : null
  ]
}