# =============================================================================
# labs/day-1/10-differentiators — provider for_each (OpenTofu 1.9)
# =============================================================================
#
# The headline of this lab: a SINGLE provider block fanned out over many
# regions with `for_each` (OpenTofu 1.9). One declaration, one instance per
# region, each addressable as `aws.by_region["<region>"]`. Terraform has no
# equivalent — you would hand-write one aliased provider block per region.

terraform {
  # provider `for_each` is an OpenTofu 1.9 feature.
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0: provider v6's waiters are incompatible with LocalStack community
      # (last release 4.9.2). v5 applies clean against :4566.
      version = ">= 5.0, < 6.0"
    }
  }
}

# One shared source of truth for the region set. The provider `for_each` and
# every regional resource iterate THIS map, so their instance keys always align.
locals {
  regions = toset(["us-east-1", "eu-west-1"])
}

# -----------------------------------------------------------------------------
# provider for_each (OpenTofu 1.9) — one AWS provider instance PER region.
# `each.key` / `each.value` are the region string; every endpoint still points
# at LocalStack (:4566), so this runs with zero real AWS credentials and cost.
# -----------------------------------------------------------------------------
provider "aws" {
  alias    = "by_region"
  for_each = local.regions
  region   = each.value

  access_key = "test"
  secret_key = "test"

  # LocalStack has no real IAM/metadata/STS; skip those handshakes.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Path-style S3 addressing is required against LocalStack.
  s3_use_path_style = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}
