# =============================================================================
# examples/naming-labels-demo — providers + state encryption
# =============================================================================

terraform {
  required_version = ">= 1.8.0" # 1.8+ for mock_provider in tests

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }

  # ---------------------------------------------------------------------------
  # STATE ENCRYPTION (OpenTofu native) — the S05 <-> S08 tie-in.
  #
  # OpenTofu encrypts state (and plan) at rest using a key derived from a
  # passphrase via PBKDF2, then AES-GCM. Supply the passphrase out-of-band:
  #
  #     export TF_ENCRYPTION='key_provider "pbkdf2" "passphrase" { passphrase = "..." }'
  #
  # OR set the passphrase env var referenced below. The passphrase MUST be at
  # least 16 characters or init fails.
  #
  # `enforced = true` (commented) would make OpenTofu REFUSE to read/write
  # unencrypted state — flip it on once every collaborator has the passphrase.
  # ---------------------------------------------------------------------------
  encryption {
    key_provider "pbkdf2" "passphrase" {
      # Read the passphrase from an env var so it never lands in VCS.
      # Set: export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "encrypted" {
      keys = key_provider.pbkdf2.passphrase
    }

    state {
      method = method.aes_gcm.encrypted
      # enforced = true  # <- uncomment to reject unencrypted state entirely
    }

    plan {
      method = method.aes_gcm.encrypted
    }
  }
}

# -----------------------------------------------------------------------------
# AWS provider. When use_localstack = true (default) it points every endpoint
# at LocalStack (http://localhost:4566) and skips all real-cloud handshakes, so
# the example runs with zero real AWS credentials and zero cost.
# -----------------------------------------------------------------------------
provider "aws" {
  region     = var.region
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  # LocalStack has no real IAM/metadata/STS; skip those handshakes.
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # Path-style S3 addressing is required against LocalStack.
  s3_use_path_style = var.use_localstack

  # Only wire the custom endpoints when talking to LocalStack; otherwise use the
  # real AWS endpoints for var.region.
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3       = "http://localhost:4566"
      dynamodb = "http://localhost:4566"
    }
  }
}
