# =============================================================================
# OVH twin of Lab 10 — unit tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# The provider is an ALIASED `for_each` fan-out (`aws.by_region[...]`), which a
# bare `mock_provider "aws" {}` does not cover. Instead the plan runs with
# dummy static credentials and every AWS-only handshake skipped, so it makes no
# API calls and needs no network. A fixed suffix makes the names known.
# =============================================================================

run "regional_fan_out" {
  command = plan

  variables {
    bucket_suffix = "a1b2"
    s3_access_key = "test"
    s3_secret_key = "test"
  }

  assert {
    condition     = length(aws_s3_bucket.regional) == 2
    error_message = "one bucket per region should be planned"
  }

  assert {
    condition     = aws_s3_bucket.regional["gra"].bucket == "s3-workshop-d-gra-data-a1b2"
    error_message = "the gra bucket name should embed the region and the naming suffix"
  }

  assert {
    condition     = aws_s3_bucket.regional["sbg"].bucket == "s3-workshop-d-sbg-data-a1b2"
    error_message = "the sbg bucket name should embed the region and the naming suffix"
  }
}
