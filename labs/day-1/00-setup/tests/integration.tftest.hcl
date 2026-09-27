# =============================================================================
# labs/day-1/00-setup — INTEGRATION test (needs LocalStack on :4566)
# -----------------------------------------------------------------------------
# The workshop's FIRST cloud-shaped apply. Lab 00's bucket is gated on
# `enable_localstack` (default false), so the unit lane never creates it; this
# suite is the coverage that was missing and the runtime referee for the
# aws-provider-v6-vs-LocalStack question.
#
# Run only by `task verify:integration` / the CI verify-integration job, which
# starts LocalStack on :4566 and exports AWS_ENDPOINT_URL. Excluded from the
# unit lane by its `integration` name.
# =============================================================================

run "localstack_bucket_apply" {
  command = apply

  variables {
    enable_localstack = true
  }

  assert {
    condition     = length(aws_s3_bucket.first) == 1
    error_message = "enable_localstack=true should create exactly one S3 bucket"
  }

  assert {
    condition     = aws_s3_bucket.first[0].bucket == "my-first-tofu-bucket"
    error_message = "bucket should be my-first-tofu-bucket, got ${aws_s3_bucket.first[0].bucket}"
  }
}
