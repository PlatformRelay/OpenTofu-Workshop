# Network unit consumed by terragrunt-style/live/network.
# Fixture only — Lab 27 never runs tofu against this tree.

resource "local_file" "network_marker" {
  filename = "${path.module}/network.marker"
  content  = "network\n"
}

output "network_name" {
  description = "Consumed by the app unit via a Terragrunt dependency block"
  value       = "fixture-network"
}
