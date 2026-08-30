# =============================================================================
# capstone BUILD VARIANT — the colony's 4th resource (Lab 26 · Part B)
# -----------------------------------------------------------------------------
# Drop-in extension for examples/capstone: an SNS events topic whose name is
# composed by modules/naming and whose tags reuse the SAME shared module.labels
# instance as the rest of the colony. This file is ONE valid implementation of
# the Part B contract — a learner submission passes on green gates, not on
# matching these bytes. It references var.project / var.environment /
# module.labels from the surrounding root, so it works both dropped into
# examples/capstone/ and standalone next to context.tf in this reference root.
# =============================================================================

variable "events_suffix" {
  description = "Optional explicit suffix for the events topic name. Null -> random 4-hex suffix."
  type        = string
  default     = null
}

module "events_name" {
  source = "../../modules/naming"

  resource_type = "aws_sns_topic"
  project       = var.project
  environment   = var.environment
  description   = "events"
  suffix        = var.events_suffix
}

resource "aws_sns_topic" "events" {
  name = module.events_name.name
  tags = module.labels.tags
}

output "events_topic_name" {
  description = "Composed SNS events-topic name."
  value       = module.events_name.name
}

# Same guardrail style as the colony root's colony_labels_complete: the
# extension must carry the full taxonomy because it reuses the shared
# module.labels instance — a hand-written tags literal fails this check.
check "events_labels_complete" {
  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(aws_sns_topic.events.tags), k)
    ])
    error_message = "events topic is missing one or more required taxonomy keys"
  }
}
