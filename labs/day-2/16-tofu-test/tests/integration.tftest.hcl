run "localstack_apply" {
  command = apply

  assert {
    condition     = can(regex("^s3-${var.expected_project}-d-web-[a-f0-9]{4}$", output.bucket_name))
    error_message = "expected project ${var.expected_project} in bucket name, got ${output.bucket_name}."
  }
}

