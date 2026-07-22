run "classify_plan_contract" {
  command = plan

  assert {
    condition     = output.actual_category == var.expected_category
    error_message = "Expected ${var.expected_category}, classified ${output.actual_category}."
  }
}
