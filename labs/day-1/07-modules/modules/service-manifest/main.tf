# Providers a module needs are declared in the module, inherited from the caller.
terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# The manifest resource extracted from S15 — one file per service. Because the
# filename derives from var.service.name, two callers with different names write
# two different files and never collide.
resource "random_pet" "release" {
  length = 2
}

resource "local_file" "manifest" {
  filename = "${path.root}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    RELEASE=${random_pet.release.id}
  EOT
}
