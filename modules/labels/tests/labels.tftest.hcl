# =============================================================================
# modules/labels — native tests (tofu test)
# All runs use `command = plan`: pure computation, no provider needed.
# =============================================================================

# --- Required-only: optional keys dropped, managed-by defaulted ---------------
run "required_only" {
  command = plan

  variables {
    environment = "prod"
    criticality = "high"
    project     = "crmapp"
    service     = "web"
    owner       = "platform-team@example.com"
    cost_center = "CC-1234"
  }

  assert {
    condition     = length(output.labels) == 7 # 6 required + managed-by default
    error_message = "expected 7 labels (6 required + managed-by), got ${length(output.labels)}"
  }

  assert {
    condition     = output.labels["managed-by"] == "opentofu"
    error_message = "managed-by should default to opentofu"
  }

  assert {
    condition     = !contains(keys(output.labels), "compliance")
    error_message = "null optional keys should be dropped"
  }

  # tags is an exact alias of labels.
  assert {
    condition     = output.tags == output.labels
    error_message = "tags must equal labels"
  }
}

# --- Full taxonomy + additional_labels merge ----------------------------------
run "full_taxonomy_and_merge" {
  command = plan

  variables {
    environment         = "prod"
    criticality         = "business-critical"
    project             = "crmapp"
    service             = "api"
    owner               = "platform-team@example.com"
    cost_center         = "CC-1234"
    compliance          = "soc2"
    data_classification = "confidential"
    primary_contact     = "alice@example.com"
    secondary_contact   = "bob@example.com"
    managed_by          = "opentofu"
    iac_source_url      = "https://git.example.com/infra/estate"
    additional_labels = {
      "team"   = "payments"
      "region" = "euw1"
    }
  }

  assert {
    # 7 always-present (6 required + managed-by) + 5 optional + 2 additional = 14
    condition     = length(output.labels) == 14
    error_message = "expected 14 merged labels, got ${length(output.labels)}"
  }

  assert {
    condition     = output.labels["data-classification"] == "confidential"
    error_message = "data-classification should be carried through"
  }

  assert {
    condition     = output.labels["team"] == "payments"
    error_message = "additional_labels should merge in"
  }
}

# --- expect_failures: invalid criticality -------------------------------------
run "invalid_criticality_fails" {
  command = plan

  variables {
    environment = "prod"
    criticality = "kinda-important" # not in the allowed set
    project     = "crmapp"
    service     = "web"
    owner       = "platform-team@example.com"
    cost_center = "CC-1234"
  }

  expect_failures = [
    var.criticality,
  ]
}

# --- expect_failures: owner not email-shaped ----------------------------------
run "invalid_owner_fails" {
  command = plan

  variables {
    environment = "prod"
    criticality = "high"
    project     = "crmapp"
    service     = "web"
    owner       = "not-an-email"
    cost_center = "CC-1234"
  }

  expect_failures = [
    var.owner,
  ]
}
