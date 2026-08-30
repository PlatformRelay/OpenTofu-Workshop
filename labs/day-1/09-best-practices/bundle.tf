# The deploy artifact: ONE zip holding every service's manifest.
# (hashicorp/archive is declared in main.tf — a module may carry
# only one required_providers block.)
# "source" is a repeated NESTED BLOCK inside this data source —
# exactly the shape dynamic blocks exist to generate.
data "archive_file" "bundle" {
  type        = "zip"
  output_path = "${path.module}/out/bundle.zip"

  # One source{} per service. The iterator is named after the
  # LABEL: source.key / source.value, not each.key / each.value.
  dynamic "source" {
    for_each = var.services
    content {
      filename = "${source.key}.env"
      content  = "REPLICAS=${source.value.replicas}\n"
    }
  }
}

output "bundle_sha256" {
  description = "Bundle checksum — changes with any manifest."
  value       = data.archive_file.bundle.output_sha256
}
