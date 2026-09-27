# =============================================================================
# OVH twin of Lab 16 — unit test (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan with a mock_provider "aws". A fixed suffix makes the composed
# name known at plan. Runs in `task ovh:verify`.
# =============================================================================

mock_provider "aws" {}

run "naming_module_wired" {
  command = plan

  variables {
    bucket_suffix = "a1b2"
  }

  assert {
    condition     = aws_s3_bucket.web.bucket == "s3-crmapp-d-web-a1b2"
    error_message = "expected the naming module to compose s3-crmapp-d-web-a1b2, got ${aws_s3_bucket.web.bucket}"
  }
}
