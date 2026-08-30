# =============================================================================
# labs/day-1/10-differentiators/import — provider wiring (LocalStack)
# =============================================================================
#
# Part B of Lab 10: adopting EXISTING infrastructure with `import`.
# One plain provider instance is enough here — the fan-out lives in
# Part A's workdir one level up. Every endpoint points at LocalStack
# (:4566): zero real AWS credentials, zero cost.

terraform {
  # `import {}` blocks are core in every supported OpenTofu release;
  # the Stretch's `for_each` on an import block needs >= 1.7.
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0: provider v6's waiters are incompatible with LocalStack
      # community (last release 4.9.2). v5 runs clean against :4566.
      version = ">= 5.0, < 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

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
