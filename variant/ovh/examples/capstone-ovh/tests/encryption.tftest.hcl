# =============================================================================
# OVH twin of the capstone — encryption contract tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# Ported from examples/capstone/tests/encryption.tftest.hcl. Guards the S05
# PBKDF2 wiring in providers.tf. Runtime encryption is disabled during
# tofu test, so encryption_contract.tf asserts the tracked HCL contract.
# Covered by `task ovh:verify`.
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "encryption_contract_plan" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    project          = "colony"
    environment      = "dev"
    state_passphrase = "unit-test-passphrase-ok"
    artifacts_suffix = "a1b2"
    archive_suffix   = "c3d4"
  }

  assert {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must be supplied for PBKDF2 encryption (>= 16 chars)"
  }
}

run "state_passphrase_too_short_rejected" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    state_passphrase = "short"
  }

  expect_failures = [
    var.state_passphrase,
  ]
}
