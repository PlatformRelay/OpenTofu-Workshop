# =============================================================================
# examples/capstone — providers + PBKDF2 state encryption
# -----------------------------------------------------------------------------
# Ties Day 1 (S05 encryption, S08 naming/labels) to Day 2 (tofu test) on one
# LocalStack root. Terramate orchestration is a stretch — see stretch/README.md.
# =============================================================================

terraform {
  required_version = ">= 1.8.0" # 1.8+ for mock_provider in tests

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0: provider v6's DynamoDB waiter is incompatible with LocalStack
      # community (last release 4.9.2) — apply hangs on "waiting for update …
      # couldn't find resource" despite DescribeTable => 200. v5 applies clean.
      version = ">= 5.0, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }

  # ---------------------------------------------------------------------------
  # STATE ENCRYPTION (OpenTofu native) — S05 ↔ capstone.
  #
  # PBKDF2 derives an AES-GCM key from a passphrase (>= 16 chars). Supply it
  # out-of-band:
  #
  #     export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
  #
  # `enforced = true` (commented) refuses unencrypted state — flip on once
  # every collaborator has the passphrase.
  # ---------------------------------------------------------------------------
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "encrypted" {
      keys = key_provider.pbkdf2.passphrase
    }

    state {
      method = method.aes_gcm.encrypted
      # enforced = true
    }

    plan {
      method = method.aes_gcm.encrypted
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  s3_use_path_style = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3       = "http://localhost:4566"
      dynamodb = "http://localhost:4566"
      sqs      = "http://localhost:4566"
    }
  }
}
