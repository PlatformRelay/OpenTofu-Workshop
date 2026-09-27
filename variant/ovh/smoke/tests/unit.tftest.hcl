# =============================================================================
# variant/ovh/smoke — unit tests (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan with a mock_provider "aws". Proves the smoke root's wiring
# (naming module + versioning + lifecycle + tagged object) plans cleanly. The
# real-OVH apply is the manual smoke run, not this lane.
# =============================================================================

mock_provider "aws" {}

run "smoke_plan" {
  command = plan

  variables {
    bucket_suffix = "a1b2"
  }

  assert {
    condition     = aws_s3_bucket.smoke.bucket == "s3-smoke-d-versioned-a1b2"
    error_message = "bucket name should be composed by modules/naming"
  }

  assert {
    condition     = aws_s3_bucket.smoke.force_destroy
    error_message = "the smoke bucket must force-destroy (it is versioned)"
  }

  assert {
    condition     = aws_s3_bucket_versioning.smoke.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must be enabled on the smoke bucket"
  }

  assert {
    condition     = aws_s3_object.tagged.tags["smoke"] == "true"
    error_message = "the smoke object must carry the smoke tag"
  }
}
