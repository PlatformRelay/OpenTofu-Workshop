# =============================================================================
# examples/naming-labels-demo — INTEGRATION test (needs LocalStack on :4566)
# -----------------------------------------------------------------------------
# command = apply against the LocalStack-pointed aws provider. Asserts the
# CONCRETE composed names — only knowable after apply, once the random suffix is
# resolved — and that labels land as real tags.
#
# This file is EXCLUDED from the unit lane (`task verify`) by its `integration`
# name and run only by `task verify:integration` / the CI LocalStack service.
# Bring the environment up first:  task lab:up
# =============================================================================

run "localstack_apply" {
  command = apply

  variables {
    use_localstack = true
    project        = "crmapp"
    environment    = "dev"
  }

  # After apply the random suffix is resolved: assert the FULL naming pattern.
  assert {
    condition     = can(regex("^s3-crmapp-d-web-[a-z0-9]{4}$", aws_s3_bucket.web.bucket))
    error_message = "bucket name should match s3-crmapp-d-web-<hex>, got ${aws_s3_bucket.web.bucket}"
  }

  assert {
    condition     = can(regex("^ddb-crmapp-d-sessions-[a-z0-9]{4}$", aws_dynamodb_table.sessions.name))
    error_message = "table name should match ddb-crmapp-d-sessions-<hex>, got ${aws_dynamodb_table.sessions.name}"
  }

  # Required labels landed on the real (LocalStack) resource as tags.
  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(aws_s3_bucket.web.tags), k)
    ])
    error_message = "all required labels must be applied as bucket tags"
  }

  assert {
    condition     = aws_dynamodb_table.sessions.tags["project"] == "crmapp"
    error_message = "table should carry the project tag"
  }
}
