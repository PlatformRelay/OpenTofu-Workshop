# =============================================================================
# OVH twin of Lab 00 — your first provider block and first bucket.
# -----------------------------------------------------------------------------
# The base lab points this provider at LocalStack; here it points at OVH Object
# Storage. Only the provider's VALUES change — the bucket resource is the same
# `aws_s3_bucket` the base lab teaches.
# =============================================================================

variable "enable_ovh" {
  description = "Create the S3 bucket on OVH. Leave false for the first local-only apply."
  type        = bool
  default     = false
}

variable "cloud_region" {
  description = "OVH S3 region code, e.g. gra, sbg, de, uk."
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
  description = "Optional explicit name suffix; null lets modules/naming generate a random one."
  type        = string
  default     = null
}

provider "aws" {
  region     = var.cloud_region
  access_key = var.s3_access_key
  secret_key = var.s3_secret_key

  # OVH is S3-compatible, not AWS: skip the AWS-only handshakes and the region
  # check (OVH region codes are not AWS-shaped).
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  # Path-style addressing is the safest against OVH.
  s3_use_path_style = true

  endpoints {
    s3 = "https://s3.${var.cloud_region}.io.cloud.ovh.net"
  }
}

# OVH bucket names are unique across ALL OVHcloud customers, so the name is
# composed by modules/naming with a random suffix rather than hardcoded.
module "bucket_name" {
  source = "../../../../../modules/naming"
  count  = var.enable_ovh ? 1 : 0

  resource_type = "aws_s3_bucket"
  project       = "first"
  environment   = "dev"
  description   = "hello"
  suffix        = var.bucket_suffix
}

resource "aws_s3_bucket" "first" {
  count  = var.enable_ovh ? 1 : 0
  bucket = module.bucket_name[0].name
}
