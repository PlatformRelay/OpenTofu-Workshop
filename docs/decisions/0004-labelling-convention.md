# 4. Labelling / tagging convention

Date: 2026-07-11

## Status

Accepted

## Context

Cloud resources accumulate without a consistent tagging scheme, cost allocation
becomes guesswork, ownership is unclear during incidents, and policy engines
have nothing reliable to match on. Free-form tags do not solve this: if every
team invents its own keys and values, the tags are not machine-queryable.

We need **one taxonomy**, applied everywhere, with **validated values** so that
tags can drive cost chargeback, inventory, compliance reporting, and automated
policy — not just decorate the console.

The convention must be:

- **Cloud-neutral.** AWS calls them "tags", other clouds call them "labels";
  the taxonomy is the same regardless.
- **Fail-closed.** A resource with missing or malformed required tags should
  fail at plan time, not ship.
- **Codified, not documented.** The taxonomy lives in a reusable `labels`
  module, so the values are validated automatically and the convention cannot
  drift into a stale wiki page.

## Decision

Adopt a **12-key taxonomy**: six required keys, six optional keys. Optional keys
that are unset are dropped from the emitted map (no empty values). The
`managed-by` key is defaulted rather than required.

| Key | Required | Allowed values / format |
|-----|:--------:|-------------------------|
| `environment` | yes | lowercase env slug (e.g. `prod`, `dev`, `staging`) |
| `criticality` | yes | one of `low`, `medium`, `high`, `critical`, `business-critical` |
| `project` | yes | lowercase project / application slug |
| `service` | yes | lowercase component slug within the project |
| `owner` | yes | owning team, email-shaped (e.g. `team@example.com`) |
| `cost-center` | yes | chargeback code (e.g. `CC-1234`) |
| `managed-by` | defaulted | managing tool; defaults to `opentofu` |
| `compliance` | optional | regime slug (e.g. `soc2`, `iso27001`, `gdpr`) |
| `data-classification` | optional | one of `public`, `internal`, `confidential`, `pii`, `phi`, `pci` |
| `primary-contact` | optional | human contact, email-shaped |
| `secondary-contact` | optional | human contact, email-shaped |
| `iac-source-url` | optional | `http(s)` link to the IaC source for provenance |

Enforcement:

- Each value is validated by a `validation {}` block in the `labels` module
  (enumerations via `contains`, emails/URLs via regex).
- An `output` `precondition` guarantees all six required keys are present and
  non-empty in the final map, even after `additional_labels` merges — a caller
  cannot blank a required key.
- An `additional_labels` map is merged last for team-specific extras, but it
  cannot remove or empty a required key.

The module emits the same map under two output names: `labels` (cloud-neutral)
and `tags` (so AWS resources read `tags = module.labels.tags` naturally).

## Consequences

**Positive**

- Cost allocation, inventory, and policy have a stable, validated set of keys.
- Ownership and criticality are discoverable during incidents.
- The convention is enforced in code; a non-compliant resource fails `tofu
  plan`, not an after-the-fact audit.

**Negative / trade-offs**

- Every team must supply the six required values; there is friction the first
  time a resource is authored. This is intentional — the friction is the point.
- Changing the taxonomy (adding a required key) is a breaking change that ripples
  to every caller. Add keys as *optional* first, then promote.
- Some providers cap tag counts / key lengths; twelve keys plus extras must stay
  within provider limits (generally fine on AWS's 50-tag limit).
