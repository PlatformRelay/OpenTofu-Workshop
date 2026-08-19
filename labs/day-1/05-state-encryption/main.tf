terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# SPINE — carried forward from stage 6, so the state you encrypt is your own
# project's state rather than a throwaway demo's.
variable "service" {
  description = "The service this config renders a manifest for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}

# SPINE — carried forward from stage 6.
variable "environment" {
  description = "Deployment environment recorded in the rendered manifest."
  type        = string
  default     = "dev"
}

# AUXILIARY — the generated secret, carried forward from stage 6 under the same
# address. No separate file records it: the value lives only in state, which is
# precisely why state has to be encrypted.
resource "random_password" "session" {
  length = 20
}

# SPINE — local_file.manifest, carried forward from stage 6.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
  EOT
}

# SPINE — output manifest_path, carried forward from stage 6.
output "manifest_path" {
  description = "Where the rendered manifest landed."
  value       = local_file.manifest.filename
}
