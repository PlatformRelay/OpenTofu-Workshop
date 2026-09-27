# =============================================================================
# variant/ovh/smoke — the real-OVH smoke root.
# -----------------------------------------------------------------------------
# Applies the EXACT shapes the twins use — an S3 bucket with versioning, a
# lifecycle rule and a tagged object — against real OVH Object Storage, then
# destroys the versioned bucket. This is the cheapest decisive proof of the
# aws-provider-against-OVH-S3 compatibility surface; run it once before the
# twins are trusted. The bucket is named via modules/naming, so the run is
# also a live check that the shared module's names are valid OVH bucket names.
# =============================================================================

module "bucket_name" {
  source = "../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = "smoke"
  environment   = "dev"
  description   = "versioned"
  suffix        = var.bucket_suffix
}

resource "aws_s3_bucket" "smoke" {
  bucket = module.bucket_name.name
  tags   = { "smoke" = "true" }

  # A versioned bucket keeps noncurrent versions and delete markers, so a plain
  # destroy fails with BucketNotEmpty. force_destroy sweeps them first.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "smoke" {
  bucket = aws_s3_bucket.smoke.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "smoke" {
  bucket = aws_s3_bucket.smoke.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_s3_object" "tagged" {
  bucket  = aws_s3_bucket.smoke.id
  key     = "smoke.txt"
  content = "ok\n"
  tags    = { "smoke" = "true" }
}
