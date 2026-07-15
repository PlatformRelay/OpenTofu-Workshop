terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# Carried forward from S06: the typed object that drives the config.
variable "service" {
  description = "The service this config renders a manifest for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}

variable "environment" {
  description = "Deployment environment. Drives the prod output precondition."
  type        = string
  default     = "dev"
}

# The postcondition's budget. Feed a tiny value with -var to break on APPLY.
variable "max_manifest_bytes" {
  description = "Byte ceiling for the rendered manifest, enforced by a postcondition."
  type        = number
  default     = 400
}

# The check's threshold. Feed a value below 16 with -var to trip the WARNING.
variable "min_secret_length" {
  description = "Minimum session-secret length. A non-blocking check warns if it is weak."
  type        = number
  default     = 24
}

# A non-sensitive, known-after-apply value — so the postcondition can read the
# rendered content at apply time without tripping OpenTofu's sensitive-value guard.
resource "random_pet" "release" {
  length = 2
}

# Generated here only to give the check a real threshold to assert on. Its value
# never lands in the manifest, so nothing sensitive leaks into the postcondition.
resource "random_password" "session" {
  length = var.min_secret_length
}

resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    RELEASE=${random_pet.release.id}
  EOT

  lifecycle {
    # precondition: evaluated at PLAN. A false condition blocks the plan before
    # any resource is touched.
    precondition {
      condition     = var.service.replicas >= 1
      error_message = "A service needs at least 1 replica (got ${var.service.replicas})."
    }

    # postcondition: references self.content, which is known-after-apply, so it
    # is evaluated at APPLY — after the file is written. A false condition fails
    # the apply (the resource is already created; only the assertion failed).
    postcondition {
      condition     = length(self.content) <= var.max_manifest_bytes
      error_message = "Rendered manifest is ${length(self.content)} bytes; budget is ${var.max_manifest_bytes}."
    }
  }
}

# An OUTPUT precondition (1.2) — evaluated at PLAN, guarding what we export.
output "manifest_path" {
  description = "Where the rendered manifest landed."
  value       = local_file.manifest.filename

  precondition {
    condition     = var.environment != "prod" || var.service.replicas >= 2
    error_message = "A prod service needs at least 2 replicas (got ${var.service.replicas})."
  }
}

# A check block (1.5) — NON-BLOCKING. Evaluated at plan AND apply; a failed
# assertion emits a WARNING and never fails the run.
check "secret_strength" {
  assert {
    condition     = var.min_secret_length >= 16
    error_message = "Session secret is ${var.min_secret_length} chars; use >= 16 for prod-grade strength."
  }
}
