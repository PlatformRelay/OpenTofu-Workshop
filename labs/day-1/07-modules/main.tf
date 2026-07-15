terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# First instance: consume the LOCAL module with the checkout service's inputs.
module "checkout" {
  source = "./modules/service-manifest"

  service = {
    name     = "checkout"
    tier     = "standard"
    replicas = 2
  }
  environment = "staging"
}

# Second instance: the SAME module, different inputs. Because service.name
# differs, this writes a separate file and applies alongside the first.
module "payments" {
  source = "./modules/service-manifest"

  service = {
    name     = "payments"
    tier     = "critical"
    replicas = 4
  }
  environment = "prod"
}

# Read each instance's outputs — the module's public contract.
output "checkout_manifest" {
  description = "Path to the checkout instance's rendered manifest."
  value       = module.checkout.manifest_path
}

output "payments_manifest" {
  description = "Path to the payments instance's rendered manifest."
  value       = module.payments.manifest_path
}
