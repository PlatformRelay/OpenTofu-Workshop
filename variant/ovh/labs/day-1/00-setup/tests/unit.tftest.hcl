# =============================================================================
# OVH twin of Lab 00 — unit tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan with a mock_provider "aws". Runs in `task ovh:verify`.
# =============================================================================

mock_provider "aws" {}

run "first_apply_is_local_only" {
  command = plan

  # Default enable_ovh = false: the first plan has no bucket.
  assert {
    condition     = length(aws_s3_bucket.first) == 0
    error_message = "with enable_ovh = false the twin must not plan a bucket"
  }
}

run "ovh_bucket_is_named_uniquely" {
  command = plan

  variables {
    enable_ovh    = true
    bucket_suffix = "a1b2"
  }

  assert {
    condition     = aws_s3_bucket.first[0].bucket == "s3-first-d-hello-a1b2"
    error_message = "the bucket name must be composed by modules/naming (unique per learner)"
  }
}
