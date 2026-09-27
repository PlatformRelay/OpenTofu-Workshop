terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
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

variable "cloud_region" {
  description = "OVH S3 region code, e.g. gra, sbg."
  type        = string
  default     = "gra"
}

variable "s3_access_key" {
  description = "OVH S3 access key. Null falls back to AWS_ACCESS_KEY_ID."
  type        = string
  default     = null
  sensitive   = true
}

variable "s3_secret_key" {
  description = "OVH S3 secret key. Null falls back to AWS_SECRET_ACCESS_KEY."
  type        = string
  default     = null
  sensitive   = true
}

variable "bucket_suffix" {
  description = "Optional explicit suffix; null lets modules/naming generate a random one."
  type        = string
  default     = null
}

provider "aws" {
  region     = var.cloud_region
  access_key = var.s3_access_key
  secret_key = var.s3_secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  s3_use_path_style = true

  endpoints {
    s3 = "https://s3.${var.cloud_region}.io.cloud.ovh.net"
  }
}

module "name" {
  source = "../../../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = "dev"
  description   = "web"
  suffix        = var.bucket_suffix
}

resource "aws_s3_bucket" "web" {
  bucket = module.name.name
}

output "bucket_name" {
  value = aws_s3_bucket.web.bucket
}
