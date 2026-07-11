# =============================================================================
# modules/naming — name composition
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Random suffix — only generated when the caller did not pass an explicit one.
# byte_length 2 -> 4 hex chars (e.g. "a1f3"). count is 0 when var.suffix is set,
# so downstream references must guard the index (see locals below).
# -----------------------------------------------------------------------------
resource "random_id" "suffix" {
  count       = var.suffix == null ? 1 : 0
  byte_length = 2
}

locals {
  # Resolve the short codes from the swappable profiles. lookup() returns "" for
  # an unknown key; the output preconditions turn that into a clear failure.
  resource_short = lookup(var.resource_short_names, var.resource_type, "")
  env_short      = lookup(var.environment_short_names, var.environment, "")

  # Guard the count index: random_id.suffix is a 0- or 1-element list.
  effective_suffix = var.suffix != null ? var.suffix : random_id.suffix[0].hex

  # Compose. compact() drops nulls AND empty strings, so optional components
  # (location, description) simply disappear when omitted.
  name_parts = compact([
    local.resource_short,
    var.project,
    local.env_short,
    var.location,
    var.description,
    local.effective_suffix,
  ])

  # lower() is defensive: inputs are already validated to be lowercase, but this
  # guarantees the invariant even if a profile override slips in an uppercase code.
  name = lower(join("-", local.name_parts))
}
