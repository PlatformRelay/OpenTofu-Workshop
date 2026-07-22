terraform {
  required_version = ">= 1.8"
}

variable "project" {
  description = "Project slug under test."
  type        = string
  default     = "crmapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{3,9}$", var.project))
    error_message = "project must be 4-10 lowercase letters or digits, starting with a letter."
  }
}

variable "expected_project" {
  description = "Expected project used by the intentional assertion exercise."
  type        = string
  default     = "crmapp"
}

resource "terraform_data" "manifest" {
  input = {
    project = var.project
  }
}

output "project" {
  value = terraform_data.manifest.output.project
}
