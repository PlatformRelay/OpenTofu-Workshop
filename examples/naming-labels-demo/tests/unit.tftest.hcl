# =============================================================================
# examples/naming-labels-demo — UNIT tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan + an ALIASED mock_provider "aws". Runs anywhere, including CI
# without Docker, and is the lane `task verify` / scripts/verify.sh executes.
#
# The mock is ALIASED so it does NOT shadow the default aws provider globally;
# only the run that opts in via `providers = { aws = aws.mock }` uses it. (A bare
# `mock_provider "aws" {}` would replace the default provider for EVERY run in
# the file — including any apply run — a false green.)
#
# The concrete composed names embed a random suffix (unknown at plan), so this
# lane asserts the KNOWN parts: the shared label map. The full-name assertions
# live in integration.tftest.hcl, which needs LocalStack.
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "unit_plan_with_mock" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    use_localstack = true
    project        = "crmapp"
    environment    = "dev"
  }

  assert {
    condition     = module.labels.labels["project"] == "crmapp"
    error_message = "project label should be crmapp"
  }

  assert {
    condition     = module.labels.labels["environment"] == "dev"
    error_message = "environment label should be dev"
  }

  # All six required label keys present (proves the taxonomy precondition held).
  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(module.labels.labels), k)
    ])
    error_message = "all required label keys must be present in the applied tags"
  }

  # managed-by defaulted, null optionals dropped.
  assert {
    condition     = module.labels.labels["managed-by"] == "opentofu"
    error_message = "managed-by should default to opentofu"
  }
}
