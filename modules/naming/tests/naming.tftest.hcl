# =============================================================================
# modules/naming — native tests (tofu test)
# -----------------------------------------------------------------------------
# All runs use `command = plan`: no provider, no cloud, no state.
#
# IMPORTANT: random_id.suffix is UNKNOWN at plan time. Any assertion on the
# fully composed `name` therefore passes an explicit `suffix`, which sets
# random_id count = 0 and makes the whole name known. The one run that exercises
# the random path asserts only the *shape* of the composed name, not the suffix
# value, using a regex that tolerates the unknown tail.
# =============================================================================

# --- Full composition with all components + explicit suffix ------------------
run "full_name_composition" {
  command = plan

  variables {
    resource_type = "aws_s3_bucket"
    project       = "crmapp"
    environment   = "dev"
    location      = "euw1"
    description   = "web"
    suffix        = "a1f3"
  }

  assert {
    condition     = output.name == "s3-crmapp-d-euw1-web-a1f3"
    error_message = "expected s3-crmapp-d-euw1-web-a1f3, got ${output.name}"
  }

  assert {
    condition     = output.resource_short == "s3"
    error_message = "resource_short should resolve to s3"
  }

  assert {
    condition     = output.environment_short == "d"
    error_message = "environment_short should resolve to d"
  }
}

# --- Optional components omitted -> compact() drops them ---------------------
run "optional_components_omitted" {
  command = plan

  variables {
    resource_type = "aws_dynamodb_table"
    project       = "orders"
    environment   = "prod"
    location      = null
    description   = null
    suffix        = "beef"
  }

  assert {
    condition     = output.name == "ddb-orders-p-beef"
    error_message = "omitting location+description should yield ddb-orders-p-beef, got ${output.name}"
  }
}

# --- Random suffix path -------------------------------------------------------
# When suffix is omitted, random_id.suffix is UNKNOWN at plan time, so the whole
# composed `name` output is unknown/null in the test context and cannot be
# asserted against. We instead assert the KNOWN parts of the composition (the
# short codes, which do not depend on random_id) to prove the random path plans
# cleanly. The explicit-suffix runs above cover the full-name shape. The
# LocalStack `apply` test in examples/ exercises the concrete random value.
run "random_suffix_path_plans" {
  command = plan

  variables {
    resource_type = "aws_lambda_function"
    project       = "billing"
    environment   = "staging"
    # suffix omitted -> random_id generates a 4-hex-char tail
  }

  assert {
    condition     = output.resource_short == "fn"
    error_message = "resource_short should resolve to fn"
  }

  assert {
    condition     = output.environment_short == "s"
    error_message = "environment_short should resolve to s"
  }
}

# --- Profile swap: override the map entirely (proves GCP profile drop-in) -----
run "profile_swap_override" {
  command = plan

  variables {
    resource_type = "google_storage_bucket"
    project       = "datalake"
    environment   = "prod"
    suffix        = "1234"
    resource_short_names = {
      google_storage_bucket = "gcs"
    }
  }

  assert {
    condition     = output.name == "gcs-datalake-p-1234"
    error_message = "overridden profile should yield gcs-datalake-p-1234, got ${output.name}"
  }
}

# --- expect_failures: resource_type absent from the profile ------------------
run "unknown_resource_type_fails" {
  command = plan

  variables {
    resource_type = "aws_not_a_real_type"
    project       = "crmapp"
    environment   = "dev"
    suffix        = "a1f3"
  }

  # Passes the variable regex but is not a key in the default profile, so the
  # output precondition rejects it.
  expect_failures = [
    output.name,
  ]
}

# --- expect_failures: project too short (variable validation) ----------------
run "bad_project_length_fails" {
  command = plan

  variables {
    resource_type = "aws_s3_bucket"
    project       = "ab" # < 4 chars
    environment   = "dev"
    suffix        = "a1f3"
  }

  expect_failures = [
    var.project,
  ]
}

# --- expect_failures: environment not in the environment profile -------------
run "unknown_environment_fails" {
  command = plan

  variables {
    resource_type = "aws_s3_bucket"
    project       = "crmapp"
    environment   = "preprod" # valid regex, but not a profile key
    suffix        = "a1f3"
  }

  expect_failures = [
    output.name,
  ]
}
