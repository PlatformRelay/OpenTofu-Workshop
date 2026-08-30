# =============================================================================
# capstone BUILD VARIANT — unit test for the events topic (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan + ALIASED mock_provider "aws", mirroring the capstone's
# tests/unit.tftest.hcl. A FIXED events_suffix makes the composed topic name
# known at plan, so the naming contract is asserted without an apply. Drop-in
# for examples/capstone/tests/ — it only references addresses that exist in
# both roots (module.events_name, aws_sns_topic.events, the shared labels).
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "build_unit_plan" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    project       = "colony"
    environment   = "dev"
    events_suffix = "f7a9"
  }

  assert {
    condition     = module.events_name.name == "sns-colony-d-events-f7a9"
    error_message = "events topic name should be sns-colony-d-events-f7a9"
  }

  assert {
    condition     = aws_sns_topic.events.name == module.events_name.name
    error_message = "the topic must take its name from the naming module, not a literal"
  }

  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(aws_sns_topic.events.tags), k)
    ])
    error_message = "events topic tags must carry the full shared label taxonomy"
  }

  assert {
    condition     = aws_sns_topic.events.tags["managed-by"] == "opentofu"
    error_message = "events topic should inherit managed-by = opentofu from the shared labels"
  }
}
