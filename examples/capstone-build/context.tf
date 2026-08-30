# =============================================================================
# examples/capstone-build — standalone context (NOT part of the drop-in)
# -----------------------------------------------------------------------------
# This root exists so the Lab 26 Part B reference implementation
# (colony_events.tf + tests/build.tftest.hcl — the two DROP-IN files) is
# validated and unit-tested by the repo's existing gates (`task verify` sweep,
# `task lab:validate DIR=examples/capstone-build`) without duplicating the
# whole colony. context.tf mirrors ONLY what the drop-ins reference from
# examples/capstone: the variables and the shared module.labels call, with the
# same values as examples/capstone/main.tf + variables.tf. It carries no
# provider config and no state encryption — those belong to the real colony
# root; the drop-ins never touch them.
# =============================================================================

terraform {
  required_version = ">= 1.8.0" # 1.8+ for mock_provider in tests

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Same ceiling as examples/capstone: LocalStack community needs < 6.0.
      version = ">= 5.0, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

variable "project" {
  description = "Project slug used for naming + the project label."
  type        = string
  default     = "colony"
}

variable "environment" {
  description = "Environment used for naming + the environment label."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owning team email for the owner label."
  type        = string
  default     = "platform-team@example.com"
}

variable "cost_center" {
  description = "Cost centre for chargeback."
  type        = string
  default     = "CC-2600"
}

# Mirrors module "labels" in examples/capstone/main.tf byte-for-value, so the
# drop-in's taxonomy assertions see the exact tag map the colony applies.
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
