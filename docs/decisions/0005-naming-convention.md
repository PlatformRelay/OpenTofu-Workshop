# 5. Resource naming convention

Date: 2026-07-11

## Status

Accepted

## Context

Resource names created ad hoc are inconsistent, collide across environments, and
carry no information. When a name is just `my-bucket`, you cannot tell from the
name what it is, which project or environment it belongs to, or where it lives —
and two teams will eventually both want `my-bucket`.

We want names that are **deterministic**, **self-describing**, and **unique**,
generated the same way for every resource, so that a name alone answers "what
kind of thing, whose, which environment, where". The convention must be enforced
in code (a reusable `naming` module) rather than left to a wiki, and it must be
**cloud-portable** — the same pattern should work whether the short codes come
from an AWS profile or a GCP profile.

## Decision

Adopt a **hyphen-joined, ordered component** name:

```text
[resource_short]-[project]-[env_short]-[location]-[description]-[suffix]
```

Example: an `aws_s3_bucket` for project `crmapp`, environment `dev`, region
token `euw1`, role `web` →

```text
s3-crmapp-d-euw1-web-a1f3
```

| Component | Source | Required | Notes |
|-----------|--------|:--------:|-------|
| `resource_short` | `resource_short_names[resource_type]` | yes | short code per resource type (e.g. `s3`, `ec2`, `rds`) |
| `project` | input | yes | 4–10 lowercase alphanumerics, starts with a letter |
| `env_short` | `environment_short_names[environment]` | yes | short code per environment (e.g. `p`, `d`, `s`) |
| `location` | input | optional | short region/zone token (e.g. `euw1`); dropped if unset |
| `description` | input | optional | role component (e.g. `web`, `api`); dropped if unset |
| `suffix` | input or generated | yes | explicit, or a random 4-hex-char suffix for uniqueness |

Rules:

- **Swappable profiles.** The `resource_type → short code` map is a *variable*,
  so a consumer can drop in an entirely different cloud profile (e.g. a GCP map
  keyed by `google_storage_bucket`) without forking the module.
- **Optional components vanish cleanly.** `location` and `description` are joined
  via `compact()`, so an unset component leaves no empty `--` gap.
- **Uniqueness by default.** When no explicit suffix is given, a `random_id`
  produces a 4-hex-char tail so repeated applications in the same scope do not
  collide.
- **Fail-closed invariants.** Every input is validated (regex/length). The
  `name` output carries preconditions guaranteeing the final name is `< 64`
  characters, matches `^[a-z0-9-]+$`, and that both the resource type and
  environment were recognised by their profiles. An invalid name can never
  reach a provider.

## Consequences

**Positive**

- A name alone tells you the kind, owner project, environment, location, and
  role of a resource.
- Names are deterministic and collision-resistant across environments.
- Porting to another cloud is a map swap, not a rewrite.

**Negative / trade-offs**

- Names are terse; readers must learn the short-code profiles (mitigated by the
  profile living in code and the `resource_short` / `environment_short` outputs).
- The `< 64` character ceiling means long project + description combinations can
  fail the precondition; authors must keep components short. This is deliberate —
  the failure surfaces at plan time, not at resource creation.
- A generated random suffix is **unknown until apply**, so tests that assert the
  full name must supply an explicit suffix (or assert after apply). This is a
  known interaction documented in the module's tests.
