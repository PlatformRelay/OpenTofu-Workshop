terraform {
  required_version = ">= 1.8"
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
variable "owner" {
  type        = string
  description = "Name recorded as the owner of the generated artifacts."
  default     = "workshop"
}

# locals — named expressions computed once and reused. Keeps interpolation
# out of the resources below.
locals {
  banner   = upper(var.owner)
  out_file = "${path.module}/build/summary.txt"
}

# data — reads something that already exists (here a tracked file on disk)
# without managing it. Its result is available as data.local_file.motd.content.
data "local_file" "motd" {
  filename = "${path.module}/motd.txt"
}

# resource — a thing OpenTofu creates, updates, and destroys. random_pet
# generates a stable identity once and stores it in state.
resource "random_pet" "id" {
  length = 2
}

# module — calls reusable config in ./greeting, passing an input and reading
# an output back. This is how you compose configurations.
module "greeting" {
  source = "./greeting"
  name   = local.banner
}

# resource — the file OpenTofu owns. Its content references the variable, the
# local, the data source, the random_pet resource, and the module output —
# every reference kind in one place.
resource "local_file" "summary" {
  filename = local.out_file
  content  = <<-EOT
    owner   = ${var.owner} (${local.banner})
    id      = ${random_pet.id.id}
    motd    = ${trimspace(data.local_file.motd.content)}
    greeting= ${module.greeting.message}
  EOT
}

# output — a value surfaced after apply and consumable by other configs.
output "summary_path" {
  description = "Where the generated summary landed."
  value       = local_file.summary.filename
}
