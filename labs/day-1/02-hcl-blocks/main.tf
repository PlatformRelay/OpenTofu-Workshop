terraform {
  required_version = ">= 1.9"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# provider — configures a plugin. `local` needs no settings; the block still
# declares that this config uses it.
provider "local" {}

# variable — a typed input. Override it with -var, a *.tfvars file, or an
# environment variable; here it defaults so the lab runs with zero flags.
# AUXILIARY: `owner` exists to demonstrate the block type. It is NOT a spine
# input — the project's own inputs (variable "service" / variable "environment")
# arrive at stage 4, labs/day-1/06-variables/. This one retires at stage 3.
variable "owner" {
  type        = string
  description = "Name recorded as the owner of the generated artifacts."
  default     = "workshop"
}

# locals — named expressions computed once and reused. Keeps interpolation
# out of the resources below.
locals {
  banner   = upper(var.owner)
  out_file = "${path.module}/build/manifest.txt"
}

# data — reads something that already exists (here a tracked file on disk)
# without managing it. Its result is available as data.local_file.motd.content.
data "local_file" "motd" {
  filename = "${path.module}/motd.txt"
}

# resource — a thing OpenTofu creates, updates, and destroys. random_pet
# generates a stable identity once and stores it in state. AUXILIARY, carried
# under the same address as stage 1: random_pet.env.
resource "random_pet" "env" {
  length = 2
}

# module — a FORWARD REFERENCE, not one of this section's taught block types.
# It calls reusable config in ./greeting, passing an input and reading an output
# back, so the manifest below can show what a module reference looks like.
# Composition itself is taught at stage 8 (S07 · Modules).
module "greeting" {
  source = "./greeting"
  name   = local.banner
}

# SPINE — local_file.manifest, carried forward from stage 1. Its content
# references the variable, the local, the data source, the random_pet resource,
# and the module output — every reference kind in one place.
resource "local_file" "manifest" {
  filename = local.out_file
  content  = <<-EOT
    owner   = ${var.owner} (${local.banner})
    env     = ${random_pet.env.id}
    motd    = ${trimspace(data.local_file.motd.content)}
    greeting= ${module.greeting.message}
  EOT
}

# SPINE — output manifest_path, carried forward from stage 1. An output is a
# value surfaced after apply and consumable by other configs.
output "manifest_path" {
  description = "Where the generated manifest landed."
  value       = local_file.manifest.filename
}
