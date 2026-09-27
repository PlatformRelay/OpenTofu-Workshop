# =============================================================================
# OVH twin of Lab 10 Part B — provider wiring for the import exercise.
# -----------------------------------------------------------------------------
# One plain provider instance is enough here; the fan-out lives one level up.
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
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
