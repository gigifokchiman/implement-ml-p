variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "http_port" {
  description = "HTTP port for ingress"
  type        = number
}

variable "https_port" {
  description = "HTTPS port for ingress"
  type        = number
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    username = string
    password = string
    database = string
  })
}

variable "cache_config" {
  description = "Cache configuration"
  type = object({
    enabled = bool
  })
}

variable "storage_config" {
  description = "Storage configuration"
  type = object({
    buckets = list(string)
  })
}
