terraform {
  required_version = ">= 1.8"
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }

  # State lives on the LOCAL backend by default. This explicit block names the
  # path so we can migrate it later with `tofu init -migrate-state`.
  backend "local" {
    path = "terraform.tfstate"
  }
}

# A generated database password. It is `sensitive`, so tofu redacts it in CLI
# output — but the RESOLVED value is still written to terraform.tfstate as
# plaintext JSON. That gap is exactly what S05 (state encryption) closes.
resource "random_password" "db" {
  length  = 20
  special = true
}

# A plain resource so `state list` has more than one entry to show, mv, and rm.
resource "random_pet" "service" {
  length = 2
}

# Records the service name (not the secret) to a file — state also stores this.
resource "local_file" "service_name" {
  filename = "${path.module}/build/service.txt"
  content  = "service = ${random_pet.service.id}\n"
}

output "service_name" {
  description = "The generated service name (safe to print)."
  value       = random_pet.service.id
}

output "db_password" {
  description = "The generated DB password — sensitive, so redacted in CLI output."
  value       = random_password.db.result
  sensitive   = true
}
