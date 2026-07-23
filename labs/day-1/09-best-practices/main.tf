terraform {
  required_providers {
    local = { source = "hashicorp/local" }
  }
}

# The services this config renders a manifest for. Each entry is one deployable
# unit, keyed by a stable name — the key, not a list position, is the identity.
variable "services" {
  type = map(object({
    replicas = number
  }))
  default = {
    checkout = { replicas = 2 }
    payments = { replicas = 4 }
    search   = { replicas = 3 }
  }
}

# for_each fan-out: instances are addressed by KEY (manifest["checkout"], …), so
# adding or removing one map entry touches only that instance — the later ones
# keep their identity. This is the removal-stability fix for the count trap.
resource "local_file" "manifest" {
  for_each = var.services

  filename = "${path.module}/out/${each.key}.env"
  content  = <<-EOT
    SERVICE_NAME=${each.key}
    REPLICAS=${each.value.replicas}
  EOT
}

# Refactor without replacement: tell OpenTofu each old count-indexed instance is
# the same object as its new keyed address. Plan resolves to a no-op state move,
# not a destroy+recreate. Order matches the original list: 0=checkout, 1=payments,
# 2=search.
moved {
  from = local_file.manifest[0]
  to   = local_file.manifest["checkout"]
}

moved {
  from = local_file.manifest[1]
  to   = local_file.manifest["payments"]
}

moved {
  from = local_file.manifest[2]
  to   = local_file.manifest["search"]
}
