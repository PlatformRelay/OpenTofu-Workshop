# Converted from an apply-style LocalStack test: mock the aws provider so a
# plan-only run needs neither credentials nor a live service (Docker can be down).

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "s3-crmapp-d-web-lab"
      arn = "arn:aws:s3:::s3-crmapp-d-web-lab"
    }
  }
}

run "mocked_bucket_plan" {
  command = plan

  # Run-level override wins over mock_resource defaults for this address.
  override_resource {
    target = aws_s3_bucket.web
    values = {
      id  = "s3-crmapp-d-web-lab"
      arn = "arn:aws:s3:::s3-crmapp-d-web-lab"
    }
  }

  assert {
    condition     = aws_s3_bucket.web.id == var.expected_bucket_id
    error_message = "expected bucket id ${var.expected_bucket_id}, got ${aws_s3_bucket.web.id}"
  }

  assert {
    condition     = aws_s3_bucket.web.arn == "arn:aws:s3:::${var.bucket_name}"
    error_message = "expected ARN for ${var.bucket_name}, got ${aws_s3_bucket.web.arn}"
  }

  assert {
    condition     = output.bucket_id == var.expected_bucket_id
    error_message = "expected output.bucket_id ${var.expected_bucket_id}, got ${output.bucket_id}"
  }
}
