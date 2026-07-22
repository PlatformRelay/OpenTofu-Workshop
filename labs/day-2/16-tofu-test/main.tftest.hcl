variables {
  project = "crmapp"
}

run "project_plan_contract" {
  command = plan

  assert {
    condition     = terraform_data.manifest.input.project == var.expected_project
    error_message = "expected ${var.expected_project}, planned ${terraform_data.manifest.input.project}."
  }
}

run "project_apply_contract" {
  command = apply

  assert {
    condition     = output.project == "crmapp"
    error_message = "applied project should be crmapp, got ${output.project}."
  }
}

run "invalid_project_is_rejected" {
  command = plan

  variables {
    project = "BAD!"
  }

  expect_failures = [
    var.project,
  ]
}
