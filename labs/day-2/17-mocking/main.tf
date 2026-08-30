terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

variable "bucket_name" {
  description = "Deterministic bucket name used by the mocked plan contract."
  type        = string
  default     = "s3-crmapp-d-web-lab"
}

variable "expected_bucket_id" {
  description = "Expected mocked bucket id asserted by the unit test."
  type        = string
  default     = "s3-crmapp-d-web-lab"
}

# Real provider config — only used when a test does NOT mock aws.
# The unit suite replaces this with mock_provider, so LocalStack can be down.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "web" {
  bucket = var.bucket_name
}

output "bucket_id" {
  description = "Bucket id from the aws_s3_bucket.web resource."
  value       = aws_s3_bucket.web.id
}

output "bucket_arn" {
  description = "Bucket ARN from the aws_s3_bucket.web resource."
  value       = aws_s3_bucket.web.arn
}
