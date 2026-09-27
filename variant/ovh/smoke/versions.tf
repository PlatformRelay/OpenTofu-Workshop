terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0 keeps the variant on the family the base labs verified; the OVH
      # S3 compatibility surface is what the smoke run proves.
      version = ">= 5.0, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

# The S3-compatible provider against OVH Object Storage. `skip_region_validation`
# is mandatory: OVH region codes (gra, sbg, …) are not AWS-shaped and the AWS
# provider rejects them unless that check is skipped.
provider "aws" {
  region                      = var.cloud_region
  access_key                  = var.s3_access_key
  secret_key                  = var.s3_secret_key
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  s3_use_path_style           = true

  endpoints {
    s3 = "https://s3.${var.cloud_region}.io.cloud.ovh.net"
  }
}
