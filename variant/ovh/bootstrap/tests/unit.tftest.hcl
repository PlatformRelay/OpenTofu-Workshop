# =============================================================================
# variant/ovh/bootstrap — unit tests (no cloud, no Docker, no OVH account)
# -----------------------------------------------------------------------------
# command = plan with a mock_provider "ovh". Runs in `task ovh:verify`.
# =============================================================================

mock_provider "ovh" {}

run "bootstrap_plan" {
  command = plan

  variables {
    ovh_service_name = "test-project"
    alert_email      = "learner@example.com"
  }

  assert {
    condition     = ovh_cloud_project_user.s3.description == "opentofu-workshop OVH variant S3 user"
    error_message = "the Object Storage user should carry the default description"
  }

  assert {
    condition     = contains(ovh_cloud_project_user.s3.role_names, "objectstore_operator")
    error_message = "the Object Storage user must carry the objectstore_operator role"
  }

  assert {
    condition     = ovh_cloud_project_alerting.budget.email == "learner@example.com"
    error_message = "the budget alert should use the configured email"
  }

  assert {
    condition     = ovh_cloud_project_alerting.budget.monthly_threshold == 10
    error_message = "the default budget alert threshold should be 10"
  }

  assert {
    condition     = ovh_cloud_project_alerting.budget.delay == 3600
    error_message = "the default alert delay should be 3600 seconds"
  }
}

run "threshold_zero_rejected" {
  command = plan

  variables {
    ovh_service_name        = "test-project"
    alert_email             = "learner@example.com"
    alert_monthly_threshold = 0
  }

  expect_failures = [
    var.alert_monthly_threshold,
  ]
}

run "invalid_endpoint_rejected" {
  command = plan

  variables {
    ovh_service_name = "test-project"
    alert_email      = "learner@example.com"
    ovh_endpoint     = "not-an-endpoint"
  }

  expect_failures = [
    var.ovh_endpoint,
  ]
}
