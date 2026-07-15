# Auto-loaded by tofu. This is the ".tfvars" tier of the precedence stack:
# it beats a variable default, but a -var flag on the CLI beats it.
environment = "staging"

service = {
  name     = "checkout"
  tier     = "standard"
  replicas = 2
}
