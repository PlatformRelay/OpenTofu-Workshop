# =============================================================================
# modules/labels — label map composition
# =============================================================================

terraform {
  required_version = ">= 1.7.0"
  # No providers: this module is pure computation over inputs.
}

locals {
  # Required keys are always present (variable validation guarantees non-empty).
  required_labels = {
    "environment" = var.environment
    "criticality" = var.criticality
    "project"     = var.project
    "service"     = var.service
    "owner"       = var.owner
    "cost-center" = var.cost_center
    "managed-by"  = var.managed_by
  }

  # Optional keys may be null. Collect them, then drop the null ones so the
  # emitted map never carries empty values.
  optional_labels_raw = {
    "compliance"          = var.compliance
    "data-classification" = var.data_classification
    "primary-contact"     = var.primary_contact
    "secondary-contact"   = var.secondary_contact
    "iac-source-url"      = var.iac_source_url
  }

  optional_labels = { for k, v in local.optional_labels_raw : k => v if v != null }

  # Merge order: taxonomy first, then caller extras win last.
  labels = merge(local.required_labels, local.optional_labels, var.additional_labels)

  # Keys that MUST always be present and non-empty in the final map.
  required_keys = ["environment", "criticality", "project", "service", "owner", "cost-center"]
}
