# Audit Logging Module Variables

variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string
  default     = "local"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}