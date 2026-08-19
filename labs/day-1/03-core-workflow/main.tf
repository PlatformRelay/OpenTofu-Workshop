terraform {
  required_version = ">= 1.8"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

provider "local" {}

# AUXILIARY, carried under the same address as stages 1-2: random_pet.env.
# Created once and stored in state, so every apply reuses it — the anchor the
# rest of the graph depends on.
resource "random_pet" "env" {
  length = 2
}

# SPINE — local_file.manifest, carried forward from stage 2. Depends on
# random_pet.env: the reference below makes OpenTofu create the pet FIRST, then
# this file. That edge is one arc of the dependency graph plan orders for you.
resource "local_file" "manifest" {
  filename = "${path.module}/build/manifest.txt"
  content  = "environment = ${random_pet.env.id}\n"
}

# AUXILIARY — a second graph node, and nothing more. It depends on
# local_file.manifest: it reads the manifest's content back, so this file can
# only be written AFTER the manifest exists. Two edges, one clear order. Its
# teaching job ends with this stage; stage 4 retires it.
resource "local_file" "summary" {
  filename = "${path.module}/build/summary.txt"
  content  = "Deployed ${trimspace(local_file.manifest.content)} via the core workflow.\n"
}

# SPINE — output manifest_path, carried forward from stage 2.
output "manifest_path" {
  description = "Where the rendered manifest landed."
  value       = local_file.manifest.filename
}
