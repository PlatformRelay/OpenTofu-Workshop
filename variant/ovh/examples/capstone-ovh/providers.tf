# =============================================================================
# OVH twin of examples/capstone — providers + PBKDF2 state encryption.
# -----------------------------------------------------------------------------
# Ties Day 1 (S05 encryption, S08 naming/labels) to Day 2 (tofu test) on one OVH
# Object Storage root. The base capstone's DynamoDB table and SQS queue become
# bucket versioning + lifecycle on the same bucket.
# =============================================================================

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

  # ---------------------------------------------------------------------------
  # STATE ENCRYPTION (OpenTofu native) — S05 <-> capstone. PBKDF2 derives an
  # AES-GCM key from a passphrase (>= 16 chars), supplied via
  # TF_VAR_state_passphrase.
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
