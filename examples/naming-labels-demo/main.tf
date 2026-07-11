# =============================================================================
# examples/naming-labels-demo — wire naming + labels into real AWS resources
# -----------------------------------------------------------------------------
# Creates an S3 bucket and a DynamoDB table, each NAMED by module.naming and
# TAGGED by module.labels. Runs against LocalStack (default) with no real cloud.
# =============================================================================

# --- Names --------------------------------------------------------------------

module "bucket_name" {
  source = "../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "web"
}

module "table_name" {
  source = "../../modules/naming"

  resource_type = "aws_dynamodb_table"
  project       = var.project
  environment   = var.environment
  description   = "sessions"
}

# --- Shared labels ------------------------------------------------------------

module "labels" {
  source = "../../modules/labels"

  environment = var.environment
  criticality = "high"
  project     = var.project
  service     = "web"
  owner       = var.owner
  cost_center = var.cost_center

  data_classification = "internal"
  iac_source_url      = "https://git.example.com/infra/naming-labels-demo"
}

# --- Resources ----------------------------------------------------------------

resource "aws_s3_bucket" "web" {
  bucket = module.bucket_name.name
  tags   = module.labels.tags
}

resource "aws_dynamodb_table" "sessions" {
  name         = module.table_name.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = module.labels.tags
}
