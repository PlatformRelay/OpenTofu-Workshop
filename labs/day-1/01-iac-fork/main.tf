terraform {
  required_version = ">= 1.8"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# A stable, generated identity for this environment. The imperative script used
# $RANDOM; here the value is declared once and tracked in state, so every run is
# reproducible instead of different each time.
resource "random_pet" "env" {
  length = 2
}

# The declarative equivalent of `echo ... > greeting.txt`. OpenTofu owns this
# file: it creates it, detects drift if it changes, and destroys it on teardown.
resource "local_file" "greeting" {
  filename        = "${path.module}/build/greeting.txt"
  file_permission = "0644"
  content         = "Hello from ${random_pet.env.id} — provisioned declaratively.\n"
}

output "greeting_path" {
  description = "Where the declaratively managed file landed."
  value       = local_file.greeting.filename
}
