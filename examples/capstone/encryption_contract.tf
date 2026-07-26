# =============================================================================
# examples/capstone — PBKDF2 encryption contract (regression guard)
# -----------------------------------------------------------------------------
# tofu test disables runtime state/plan encryption, so unit tests cannot inspect
# ciphertext. This check reads providers.tf and fails plan when the S05 wiring
# (PBKDF2 key provider → AES-GCM → state + plan) or passphrase variable link
# is removed or renamed.
# =============================================================================

locals {
  providers_tf = file("${path.module}/providers.tf")
}

check "pbkdf2_state_encryption_wired" {
  assert {
    condition = alltrue([
      can(regex("encryption \\{", local.providers_tf)),
      can(regex("key_provider \"pbkdf2\" \"passphrase\"", local.providers_tf)),
      can(regex("passphrase = var.state_passphrase", local.providers_tf)),
      can(regex("method \"aes_gcm\" \"encrypted\"", local.providers_tf)),
      can(regex("keys = key_provider.pbkdf2.passphrase", local.providers_tf)),
      can(regex("method = method.aes_gcm.encrypted", local.providers_tf)),
    ])
    error_message = "providers.tf must keep PBKDF2 state/plan encryption wired to var.state_passphrase"
  }
}
