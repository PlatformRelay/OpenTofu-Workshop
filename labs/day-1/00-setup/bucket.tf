variable "enable_localstack" {
  description = "Create the S3 bucket after LocalStack is healthy."
  type        = bool
  default     = false
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "first" {
  count  = var.enable_localstack ? 1 : 0
  bucket = "my-first-tofu-bucket"
}
