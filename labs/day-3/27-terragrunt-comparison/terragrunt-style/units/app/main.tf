# App unit consumed by terragrunt-style/live/app.
# Fixture only — Lab 27 never runs tofu against this tree.

variable "network_name" {
  description = "Wired by Terragrunt from dependency.network.outputs"
  type        = string
}

resource "local_file" "app_marker" {
  filename = "${path.module}/app.marker"
  content  = "app on ${var.network_name}\n"
}
