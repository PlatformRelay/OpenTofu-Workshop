# Auto-loaded by tofu. Carries the S06 service object forward so this lab starts
# from a known-good baseline; the Steps override individual values with -var.
environment = "staging"

service = {
  name     = "checkout"
  tier     = "standard"
  replicas = 2
}
