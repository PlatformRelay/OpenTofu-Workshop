terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

variable "project" {
  description = "Project slug used in the deterministic bucket name."
  type        = string
  default     = "crmapp"
}

variable "aws_endpoint" {
  description = "S3 API endpoint. Host labs use localhost; the Terratest container uses the Compose DNS name localstack."
  type        = string
  default     = "http://localhost:4566"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3 = var.aws_endpoint
  }
}

resource "aws_s3_bucket" "web" {
  bucket = "s3-${var.project}-d-web-tt"
}

output "bucket_name" {
  value = aws_s3_bucket.web.bucket
}
