# =============================================================================
# examples/capstone — INTEGRATION test (needs LocalStack on :4566)
# -----------------------------------------------------------------------------
# Excluded from the unit lane by the `integration` name; run via
# `task verify:integration` / CI LocalStack service after `task lab:up`.
# =============================================================================

run "localstack_apply" {
  command = apply

  variables {
    use_localstack   = true
    project          = "colony"
    environment      = "dev"
    state_passphrase = "integration-test-passphrase"
  }

  assert {
    condition     = can(regex("^s3-colony-d-artifacts-[a-z0-9]{4}$", aws_s3_bucket.artifacts.bucket))
    error_message = "bucket name should match s3-colony-d-artifacts-<hex>, got ${aws_s3_bucket.artifacts.bucket}"
  }

  assert {
    condition     = can(regex("^ddb-colony-d-index-[a-z0-9]{4}$", aws_dynamodb_table.index.name))
    error_message = "table name should match ddb-colony-d-index-<hex>, got ${aws_dynamodb_table.index.name}"
  }

  assert {
    condition     = can(regex("^sqs-colony-d-work-[a-z0-9]{4}$", aws_sqs_queue.work.name))
    error_message = "queue name should match sqs-colony-d-work-<hex>, got ${aws_sqs_queue.work.name}"
  }

  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(aws_s3_bucket.artifacts.tags), k)
    ])
    error_message = "all required labels must be applied as bucket tags"
  }

  assert {
    condition     = aws_dynamodb_table.index.tags["project"] == "colony"
    error_message = "table should carry the project tag"
  }

  assert {
    condition     = aws_sqs_queue.work.tags["service"] == "colony"
    error_message = "queue should carry the service tag"
  }
}
