# =============================================================================
# OVH twin of examples/naming-labels-demo — providers + state encryption.
# -----------------------------------------------------------------------------
# Same lesson as the base example (compose names with modules/naming, tag with
# modules/labels), on OVH Object Storage. The DynamoDB table of the base demo is
# dropped: the composition lesson needs one named+tagged resource, and OVH's S3
# surface is the variant's universe.
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
  # STATE ENCRYPTION (OpenTofu native) — the S05 <-> S08 tie-in.
  #
  # PBKDF2 derives an AES-GCM key from a passphrase (>= 16 chars), supplied via
  # TF_VAR_state_passphrase. `enforced = true` (commented) would refuse to
  # read/write unencrypted state.
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

  # OVH is S3-compatible, not AWS: skip the AWS-only handshakes and the region
  # check (OVH region codes are not AWS-shaped).
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  s3_use_path_style = true

  endpoints {
    s3 = "https://s3.${var.cloud_region}.io.cloud.ovh.net"
  }
}
