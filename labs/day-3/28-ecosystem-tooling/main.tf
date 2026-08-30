terraform {
  required_version = ">= 1.9"
}

variable "docs_owner" {
  description = "Team that owns generated module documentation."
  type        = string
  default     = "platform"
}

output "gate_summary" {
  description = "One-line summary of the local quality gates."
  value       = "fmt, docs, and hooks guard ${var.docs_owner} commits"
}
