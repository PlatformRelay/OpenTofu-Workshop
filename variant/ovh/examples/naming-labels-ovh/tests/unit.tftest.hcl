# =============================================================================
# OVH twin of naming-labels-demo — unit tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan with an ALIASED mock_provider "aws" (so it never shadows the
# default provider globally). A fixed suffix makes the composed name known.
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "unit_plan_with_mock" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    bucket_suffix    = "a1b2"
    project          = "crmapp"
    environment      = "dev"
    state_passphrase = "unit-test-passphrase-ok"
  }

  assert {
    condition     = module.bucket_name.name == "s3-crmapp-d-web-a1b2"
    error_message = "bucket name should be composed by modules/naming"
  }

  assert {
    condition     = module.labels.labels["project"] == "crmapp"
    error_message = "project label should be crmapp"
  }

  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(module.labels.labels), k)
    ])
    error_message = "all required label keys must be present"
  }

  assert {
    condition     = module.labels.labels["managed-by"] == "opentofu"
    error_message = "managed-by should default to opentofu"
  }
}
