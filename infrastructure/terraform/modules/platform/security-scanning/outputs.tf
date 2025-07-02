output "scanner_endpoints" {
  description = "Security scanner service endpoints"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].scanner_endpoints : {}
    ) : (
    length(module.aws_security_scanning) > 0 ? module.aws_security_scanning[0].scanner_endpoints : {}
  )
}

output "vulnerability_database" {
  description = "Vulnerability database information"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].vulnerability_database : {}
    ) : (
    length(module.aws_security_scanning) > 0 ? module.aws_security_scanning[0].vulnerability_database : {}
  )
}

output "scan_reports_location" {
  description = "Location where scan reports are stored"
  value = var.environment == "local" ? (
    length(module.kubernetes_security_scanning) > 0 ? module.kubernetes_security_scanning[0].scan_reports_location : ""
    ) : (
    length(module.aws_security_scanning) > 0 ? module.aws_security_scanning[0].scan_reports_location : ""
  )
}