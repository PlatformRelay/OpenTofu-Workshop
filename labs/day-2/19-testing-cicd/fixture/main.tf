terraform {
  required_version = ">= 1.8"
}

output "pipeline_fixture" {
  description = "Canonically formatted marker for the S19 fmt-gate exercise."
  value       = "green"
}
