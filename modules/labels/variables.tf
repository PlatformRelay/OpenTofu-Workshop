# =============================================================================
# modules/labels — input variables
# -----------------------------------------------------------------------------
# Implements the 12-key labelling taxonomy:
#   REQUIRED (6): environment, criticality, project, service, owner, cost-center
#   OPTIONAL (6): compliance, data-classification, primary-contact,
#                 secondary-contact, managed-by, iac-source-url
#
# Optional keys default to null and are DROPPED from the emitted map, so tags
# never carry empty strings. Every value is validated so the taxonomy stays
# machine-queryable (cost allocation, policy, inventory).
# =============================================================================

# --- Required -----------------------------------------------------------------

variable "environment" {
  description = "Deployment environment (e.g. prod, dev, staging)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.environment))
    error_message = "environment must be 2-20 lowercase alphanumerics/hyphens starting with a letter."
  }
}

variable "criticality" {
  description = "Business criticality of the resource."
  type        = string

  validation {
    condition     = contains(["low", "medium", "high", "critical", "business-critical"], var.criticality)
    error_message = "criticality must be one of: low, medium, high, critical, business-critical."
  }
}

variable "project" {
  description = "Project / application this resource belongs to."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,29}$", var.project))
    error_message = "project must be 2-30 lowercase alphanumerics/hyphens starting with a letter."
  }
}

variable "service" {
  description = "Service / component name within the project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,29}$", var.service))
    error_message = "service must be 2-30 lowercase alphanumerics/hyphens starting with a letter."
  }
}

variable "owner" {
  description = "Owning team distribution list or identity (email-ish)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner))
    error_message = "owner must look like an email address (e.g. team@example.com)."
  }
}

variable "cost_center" {
  description = "Cost centre / billing code for chargeback."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{2,20}$", var.cost_center))
    error_message = "cost_center must be 2-20 alphanumerics/hyphens (e.g. CC-1234)."
  }
}

# --- Optional (default null -> dropped from output) ---------------------------

variable "compliance" {
  description = "Optional compliance regime (e.g. soc2, iso27001, gdpr)."
  type        = string
  default     = null

  validation {
    condition     = var.compliance == null || can(regex("^[a-z0-9-]{2,20}$", var.compliance))
    error_message = "compliance must be 2-20 lowercase alphanumerics/hyphens, or null."
  }
}

variable "data_classification" {
  description = "Optional data sensitivity classification."
  type        = string
  default     = null

  validation {
    condition     = var.data_classification == null || contains(["public", "internal", "confidential", "pii", "phi", "pci"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, pii, phi, pci (or null)."
  }
}

variable "primary_contact" {
  description = "Optional primary human contact (email-ish)."
  type        = string
  default     = null

  validation {
    condition     = var.primary_contact == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.primary_contact))
    error_message = "primary_contact must look like an email address, or null."
  }
}

variable "secondary_contact" {
  description = "Optional secondary human contact (email-ish)."
  type        = string
  default     = null

  validation {
    condition     = var.secondary_contact == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.secondary_contact))
    error_message = "secondary_contact must look like an email address, or null."
  }
}

variable "managed_by" {
  description = "Tool that manages this resource. Defaults to opentofu."
  type        = string
  default     = "opentofu"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.managed_by))
    error_message = "managed_by must be 2-20 lowercase alphanumerics/hyphens."
  }
}

variable "iac_source_url" {
  description = "Optional URL to the IaC source (repo / module) for provenance."
  type        = string
  default     = null

  validation {
    condition     = var.iac_source_url == null || can(regex("^https?://[^\\s]+$", var.iac_source_url))
    error_message = "iac_source_url must be an http(s) URL, or null."
  }
}

# --- Escape hatch -------------------------------------------------------------

variable "additional_labels" {
  description = "Free-form extra labels merged on top of the taxonomy (e.g. per-team tags)."
  type        = map(string)
  default     = {}
}
