variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enabled" {
  description = "Whether to deploy the storage provisioner"
  type        = bool
  default     = true
}