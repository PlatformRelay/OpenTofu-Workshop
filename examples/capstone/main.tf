# =============================================================================
# examples/capstone — settled-colony LocalStack root
# -----------------------------------------------------------------------------
# Composes modules/naming + modules/labels into a small three-resource estate:
#   • S3 bucket     — artifact store
#   • DynamoDB table — metadata index
#   • SQS queue     — async work queue
#
# Base path: plain `tofu` (no Terramate required). Stretch orchestration lives
# under stretch/ and is documented there.
# =============================================================================

# --- Names --------------------------------------------------------------------

module "artifacts_name" {
  source = "../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "artifacts"
  suffix        = var.artifacts_suffix
}

module "index_name" {
  source = "../../modules/naming"

  resource_type = "aws_dynamodb_table"
  project       = var.project
  environment   = var.environment
  description   = "index"
  suffix        = var.index_suffix
}

module "queue_name" {
  source = "../../modules/naming"

  resource_type = "aws_sqs_queue"
  project       = var.project
  environment   = var.environment
  description   = "work"
  suffix        = var.queue_suffix
}

# --- Shared labels ------------------------------------------------------------

module "labels" {
  source = "../../modules/labels"

  environment = var.environment
  criticality = "medium"
  project     = var.project
  service     = "colony"
  owner       = var.owner
  cost_center = var.cost_center

  data_classification = "internal"
  iac_source_url      = "https://git.example.com/infra/capstone"
}

# --- Resources ----------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket = module.artifacts_name.name
  tags   = module.labels.tags
}

resource "aws_dynamodb_table" "index" {
  name         = module.index_name.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = module.labels.tags
}

resource "aws_sqs_queue" "work" {
  name = module.queue_name.name
  tags = module.labels.tags
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
