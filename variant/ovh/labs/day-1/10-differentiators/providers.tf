# =============================================================================
# OVH twin of Lab 10 — provider for_each over OVH regions.
# -----------------------------------------------------------------------------
# The headline is unchanged: ONE `provider "aws"` block fanned out over a set of
# regions with `for_each` (OpenTofu 1.9). Here each instance points at its OVH
# S3 endpoint instead of LocalStack.
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

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

# One shared source of truth for the region set. The provider `for_each` and
# every regional resource iterate THIS map, so their instance keys align.
locals {
  regions = toset(["gra", "sbg"])
}

# One AWS provider instance PER region, each against that region's OVH S3
# endpoint. `each.key` / `each.value` is the OVH region code.
provider "aws" {
  alias    = "by_region"
  for_each = local.regions
  region   = each.value

  access_key = var.s3_access_key
  secret_key = var.s3_secret_key

  # OVH is S3-compatible, not AWS: skip the AWS-only handshakes and the region
  # check.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  s3_use_path_style = true

  endpoints {
    s3 = "https://s3.${each.value}.io.cloud.ovh.net"
  }
}
