# =============================================================================
# modules/naming — outputs
# -----------------------------------------------------------------------------
# The `name` output carries four preconditions. These are the last line of
# defence: even if a caller overrides a profile with something odd, an invalid
# name can never leave this module.
# =============================================================================

output "name" {
  description = "The composed, validated resource name."
  value       = local.name

  precondition {
    condition     = contains(keys(var.resource_short_names), var.resource_type)
    error_message = "resource_type \"${var.resource_type}\" is not in resource_short_names. Add it to the profile or pass a map override."
  }

  precondition {
    condition     = contains(keys(var.environment_short_names), var.environment)
    error_message = "environment \"${var.environment}\" is not in environment_short_names. Add it to the profile."
  }

  precondition {
    # Most cloud resource names cap around 63-64 chars; keep a hard ceiling.
    condition     = length(local.name) < 64
    error_message = "composed name \"${local.name}\" is ${length(local.name)} chars; must be < 64. Shorten project/description."
  }

  precondition {
    condition     = can(regex("^[a-z0-9-]+$", local.name))
    error_message = "composed name \"${local.name}\" contains characters outside [a-z0-9-]."
  }
}

output "resource_short" {
  description = "The short code resolved for resource_type (useful for debugging profiles)."
  value       = local.resource_short
}

output "environment_short" {
  description = "The short code resolved for environment."
  value       = local.env_short
}

output "suffix" {
  description = "The effective suffix (explicit or generated)."
  value       = local.effective_suffix
}
