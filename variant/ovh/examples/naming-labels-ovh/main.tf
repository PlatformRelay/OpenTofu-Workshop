# =============================================================================
# OVH twin of examples/naming-labels-demo — wire naming + labels into an OVH
# bucket.
# -----------------------------------------------------------------------------
# One S3 bucket, NAMED by module.naming and TAGGED by module.labels. The base
# demo also creates a DynamoDB table; that is dropped here (S3-only variant).
# =============================================================================

module "bucket_name" {
  source = "../../../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "web"
  suffix        = var.bucket_suffix
}

module "labels" {
  source = "../../../../modules/labels"

  environment = var.environment
  criticality = "high"
  project     = var.project
  service     = "web"
  owner       = var.owner
  cost_center = var.cost_center

  data_classification = "internal"
  iac_source_url      = "https://git.example.com/infra/naming-labels-ovh"
}

resource "aws_s3_bucket" "web" {
  bucket = module.bucket_name.name
  tags   = module.labels.tags
}
