terraform {
  required_version = ">= 1.8"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

provider "local" {}

# A stable, generated release name. Created once and stored in state, so every
# apply reuses it — the anchor the rest of the graph depends on.
resource "random_pet" "release" {
  length = 2
}

# Depends on random_pet.release: the reference below makes OpenTofu create the
# pet FIRST, then this file. That edge is one arc of the dependency graph plan
# orders for you.
resource "local_file" "manifest" {
  filename = "${path.module}/build/manifest.txt"
  content  = "release = ${random_pet.release.id}\n"
}

# Depends on local_file.manifest: it reads the manifest's content back, so this
# file can only be written AFTER the manifest exists. Two edges, one clear order.
resource "local_file" "summary" {
  filename = "${path.module}/build/summary.txt"
  content  = "Deployed ${trimspace(local_file.manifest.content)} via the core workflow.\n"
}

output "release_name" {
  description = "The generated release name recorded in the manifest."
  value       = random_pet.release.id
}
