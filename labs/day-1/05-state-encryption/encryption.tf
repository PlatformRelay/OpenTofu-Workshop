terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "secure" {
      keys = key_provider.pbkdf2.passphrase
    }
    state { method = method.aes_gcm.secure }
    plan { method = method.aes_gcm.secure }

    # enforced = true  # reject any plaintext state/plan
  }
}
