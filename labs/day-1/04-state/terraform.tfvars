# Auto-loaded by tofu. Carries the stage-5 service object forward so this lab
# runs non-interactively; the Steps never override it.
environment = "staging"

service = {
  name     = "checkout"
  tier     = "standard"
  replicas = 2
}
