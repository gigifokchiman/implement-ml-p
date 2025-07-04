variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "http_port" {
  description = "HTTP port for ingress"
  type        = number
  default     = 8080
}

variable "https_port" {
  description = "HTTPS port for ingress"
  type        = number
  default     = 8443
}