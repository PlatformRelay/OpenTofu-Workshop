# =============================================================================
# OVH twin of examples/capstone — settled-colony on OVH Object Storage.
# -----------------------------------------------------------------------------
# Composes modules/naming + modules/labels into a small estate:
#   • artifacts bucket — versioned, with a lifecycle rule (replaces the base
#     capstone's DynamoDB index + SQS work queue)
#   • archive bucket   — the Part B analogue: a second named+tagged bucket
#
# Naming scope: the base capstone named three resource
# types; versioning and lifecycle are bucket sub-resources with no name and no
# tags, so this twin names ONE type (`aws_s3_bucket`) twice. The surviving
# lesson is shared-labels + the check block over a reduced resource set.
# =============================================================================

module "artifacts_name" {
  source = "../../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "artifacts"
  suffix        = var.artifacts_suffix
}

module "archive_name" {
  source = "../../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "archive"
  suffix        = var.archive_suffix
}

module "labels" {
  source = "../../../../modules/labels"

  environment = var.environment
  criticality = "medium"
  project     = var.project
  service     = "colony"
  owner       = var.owner
  cost_center = var.cost_center

  data_classification = "internal"
  iac_source_url      = "https://git.example.com/infra/capstone-ovh"
}

# --- Artifacts bucket: versioning + lifecycle replace the table/queue ---------

resource "aws_s3_bucket" "artifacts" {
  bucket = module.artifacts_name.name
  tags   = module.labels.tags

  # Versioned buckets keep noncurrent versions and delete markers, so a plain
  # destroy fails BucketNotEmpty. force_destroy sweeps them first.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# --- Archive bucket: the Part B analogue (a second named+tagged bucket) ------

resource "aws_s3_bucket" "archive" {
  bucket = module.archive_name.name
  tags   = module.labels.tags
}

# --- Guardrail (S15 tie-in) ---------------------------------------------------

check "colony_labels_complete" {
  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(module.labels.labels), k)
    ])
    error_message = "capstone label map is missing one or more required taxonomy keys"
  }
}
