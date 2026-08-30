terraform {
  required_version = ">= 1.9"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# A stable, generated identity for this environment. The imperative script used
# $RANDOM; here the value is declared once and tracked in state, so every run is
# reproducible instead of different each time. AUXILIARY: it stands in for the
# environment name until stage 4 introduces the real variable "environment".
resource "random_pet" "env" {
  length = 2
}

# SPINE — the project starts here. local_file.manifest is the rendered service
# manifest every later Day-1 stage still declares; it is never renamed. The
# declarative equivalent of `printf ... > manifest.txt`: OpenTofu owns this file,
# creates it, detects drift if it changes, and destroys it on teardown.
resource "local_file" "manifest" {
  filename        = "${path.module}/build/manifest.txt"
  file_permission = "0644"
  content         = "service = service-manifest\nenvironment = ${random_pet.env.id}\n"
}

# SPINE — the manifest's path, surfaced under the name every later stage reuses.
output "manifest_path" {
  description = "Where the declaratively managed manifest landed."
  value       = local_file.manifest.filename
}
