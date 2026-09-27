# =============================================================================
# OVH twin of Lab 16 — INTEGRATION test (needs real OVH S3 credentials)
# -----------------------------------------------------------------------------
# Excluded from the unit lane by its `integration` name; run by the (held)
# real-OVH lane or by hand with S3 credentials exported. Bring the environment
# up first: export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_DEFAULT_REGION.
# =============================================================================

run "ovh_apply" {
  command = apply

  assert {
    condition     = can(regex("^s3-${var.expected_project}-d-web-[a-f0-9]{4}$", output.bucket_name))
    error_message = "expected project ${var.expected_project} in bucket name, got ${output.bucket_name}."
  }
}
