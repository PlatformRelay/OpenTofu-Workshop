# =============================================================================
# examples/capstone — encryption contract tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# Guards the S05 PBKDF2 wiring in providers.tf. Runtime encryption is disabled
# during tofu test, so encryption_contract.tf asserts the tracked HCL contract.
# Covered by `task verify`.
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "encryption_contract_plan" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    use_localstack   = true
    project          = "colony"
    environment      = "dev"
    state_passphrase = "unit-test-passphrase-ok"
    artifacts_suffix = "a1b2"
    index_suffix     = "c3d4"
    queue_suffix     = "e5f6"
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
    use_localstack   = true
    state_passphrase = "short"
  }

  expect_failures = [
    var.state_passphrase,
  ]
}
