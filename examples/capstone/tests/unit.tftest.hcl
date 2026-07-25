# =============================================================================
# examples/capstone — UNIT tests (no cloud, no Docker, no Terramate)
# -----------------------------------------------------------------------------
# command = plan + ALIASED mock_provider "aws". Covered by `task verify`.
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "unit_plan_with_mock" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    use_localstack   = true
    project          = "colony"
    environment      = "dev"
    artifacts_suffix = "a1b2"
    index_suffix     = "c3d4"
    queue_suffix     = "e5f6"
  }

  assert {
    condition     = module.labels.labels["project"] == "colony"
    error_message = "project label should be colony"
  }

  assert {
    condition     = module.labels.labels["environment"] == "dev"
    error_message = "environment label should be dev"
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
    error_message = "all required label keys must be present in the applied tags"
  }

  assert {
    condition     = module.labels.labels["managed-by"] == "opentofu"
    error_message = "managed-by should default to opentofu"
  }

  # Fixed suffixes → full names known at plan (proves naming modules wire in).
  assert {
    condition     = module.artifacts_name.name == "s3-colony-d-artifacts-a1b2"
    error_message = "artifacts name should be s3-colony-d-artifacts-a1b2"
  }

  assert {
    condition     = module.index_name.name == "ddb-colony-d-index-c3d4"
    error_message = "index name should be ddb-colony-d-index-c3d4"
  }

  assert {
    condition     = module.queue_name.name == "sqs-colony-d-work-e5f6"
    error_message = "queue name should be sqs-colony-d-work-e5f6"
  }
}
