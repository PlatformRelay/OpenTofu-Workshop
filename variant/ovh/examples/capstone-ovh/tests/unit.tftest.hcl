# =============================================================================
# OVH twin of the capstone — unit tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan with an ALIASED mock_provider "aws". Fixed suffixes make the
# composed names known at plan.
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "unit_plan_with_mock" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    state_passphrase = "unit-test-passphrase-ok"
    artifacts_suffix = "a1b2"
    archive_suffix   = "c3d4"
  }

  assert {
    condition     = module.artifacts_name.name == "s3-colony-d-artifacts-a1b2"
    error_message = "artifacts name should be s3-colony-d-artifacts-a1b2"
  }

  assert {
    condition     = module.archive_name.name == "s3-colony-d-archive-c3d4"
    error_message = "archive name should be s3-colony-d-archive-c3d4"
  }

  assert {
    condition     = module.labels.labels["service"] == "colony"
    error_message = "service label should be colony"
  }

  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(module.labels.labels), k)
    ])
    error_message = "all required label keys must be present"
  }

  assert {
    condition     = aws_s3_bucket.artifacts.force_destroy
    error_message = "the versioned artifacts bucket must force-destroy"
  }

  assert {
    condition     = aws_s3_bucket_versioning.artifacts.versioning_configuration[0].status == "Enabled"
    error_message = "the artifacts bucket must have versioning enabled"
  }
}
