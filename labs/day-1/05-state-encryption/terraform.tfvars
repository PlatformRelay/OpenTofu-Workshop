# Auto-loaded by tofu. Carries the stage-6 service object forward so this lab
# runs non-interactively; the passphrase comes from TF_VAR_state_passphrase.
environment = "staging"

service = {
  name     = "checkout"
  tier     = "standard"
  replicas = 2
}
