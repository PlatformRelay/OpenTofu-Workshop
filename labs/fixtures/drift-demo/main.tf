# labs/fixtures/drift-demo/main.tf — reference workdir for the slide↔lab drift lane.
# A self-contained, provider-free config so `tofu fmt`/`validate` run offline.
terraform {
  required_version = ">= 1.9"
}

locals {
  greeting = "hello, opentofu"
}

output "greeting" {
  value = local.greeting
}
