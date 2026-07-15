terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# A typed object variable: one value, several fields, each with its own type.
variable "service" {
  description = "The service this config provisions a credential file for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })

  # Cross-variable validation (OpenTofu 1.9+): the condition reads BOTH this
  # variable and var.environment. A rule can now reason about the whole config,
  # not just its own value.
  validation {
    condition     = !(var.environment == "prod" && var.service.replicas < 2)
    error_message = "A prod service needs at least 2 replicas (got ${var.service.replicas})."
  }
}

variable "environment" {
  description = "Deployment environment. Drives the prod replica rule above."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# A sensitive variable never prints its value in plan/apply/output.
variable "api_token" {
  description = "A secret the service authenticates with. Marked sensitive."
  type        = string
  sensitive   = true
  default     = "dev-placeholder-token"
}

# A generated secret — the kind of value that lands in state (see S05).
resource "random_password" "session" {
  length = 20
}

# The object variable drives a real file: types in, artifact out.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    API_TOKEN=${var.api_token}
    SESSION_SECRET=${random_password.session.result}
  EOT
}

output "manifest_path" {
  description = "Where the rendered credential file landed."
  value       = local_file.manifest.filename
}

# Echoes the winning environment value so the precedence stack is visible in
# `tofu output` without opening the rendered file.
output "effective_environment" {
  description = "Whichever source won for var.environment (default < tfvars < -var)."
  value       = var.environment
}

# A sensitive output surfaces as <sensitive> unless explicitly unmasked.
output "api_token" {
  description = "Echoes the token — but sensitive, so it prints as <sensitive>."
  value       = var.api_token
  sensitive   = true
}
