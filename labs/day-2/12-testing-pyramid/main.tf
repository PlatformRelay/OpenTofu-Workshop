terraform {
  required_version = ">= 1.8"
}

variable "expected_category" {
  description = "Expected contract classification used by the plan-only test."
  type        = string
  default     = "unit-contract"
}

locals {
  actual_category = "unit-contract"
}

output "actual_category" {
  description = "The boundary exercised by this fixture."
  value       = local.actual_category
}
