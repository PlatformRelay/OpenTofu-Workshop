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
  description = "Project slug passed to the naming module."
  type        = string
  default     = "crmapp"
}

variable "expected_project" {
  description = "Expected project used by the intentional assertion exercise."
  type        = string
  default     = "crmapp"
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
    s3 = "http://localhost:4566"
  }
}

module "name" {
  source = "../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = "dev"
  description   = "web"
}

resource "aws_s3_bucket" "web" {
  bucket = module.name.name
}

output "bucket_name" {
  value = aws_s3_bucket.web.bucket
}
