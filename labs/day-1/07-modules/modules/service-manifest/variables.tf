# The module's INPUT contract. A caller passes these; nothing else leaks in.
variable "service" {
  description = "The service this module renders a manifest for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}

variable "environment" {
  description = "Deployment environment recorded in the rendered manifest."
  type        = string
  default     = "dev"
}
