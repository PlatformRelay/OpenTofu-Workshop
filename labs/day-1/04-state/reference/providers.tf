# Step 8d of Lab 04 — a SECOND config that only reads the adopted bucket.
# It has its own state, and a data source never puts the bucket in it.
# Every endpoint points at LocalStack (:4566): no real AWS, no credentials.
terraform {
  # `import {}` blocks arrived in OpenTofu 1.5; the lab floor (1.9) covers it.
  required_version = ">= 1.9"

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
  region     = "us-east-1"
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
