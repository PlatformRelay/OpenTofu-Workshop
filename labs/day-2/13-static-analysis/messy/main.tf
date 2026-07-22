terraform {
 required_version = ">= 1.8"
}

variable "service_names" {
  description = "Services included in the static-analysis exercise."
 type = list(string)
  default = "payments"
}

variable "legacy_name" {
  description = "Deliberately unused so TFLint has a semantic finding."
  type        = string
  default     = "retired"
}

output "service_count" {
  description = "Number of configured services."
 value = length(var.service_names)
}
