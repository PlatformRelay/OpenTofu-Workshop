# =============================================================================
# modules/labels — outputs
# -----------------------------------------------------------------------------
# `labels` and `tags` are the SAME map. `tags` exists purely as an ergonomic
# alias so AWS resources can write `tags = module.labels.tags` and other clouds
# (which call them "labels") can write `labels = module.labels.labels`.
# =============================================================================

output "labels" {
  description = "The composed taxonomy map (cloud-neutral name)."
  value       = local.labels

  precondition {
    # Belt-and-braces: every required key present AND non-empty in the final map,
    # even after additional_labels merges. Guards against a caller blanking a
    # required key via additional_labels.
    condition = alltrue([
      for k in local.required_keys :
      contains(keys(local.labels), k) && length(trimspace(lookup(local.labels, k, ""))) > 0
    ])
    error_message = "all required label keys (${join(", ", local.required_keys)}) must be present and non-empty."
  }
}

output "tags" {
  description = "Alias of `labels`, for AWS `tags = ...` usage."
  value       = local.labels
}
