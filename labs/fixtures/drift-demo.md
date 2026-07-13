# Fixture — slide↔lab drift self-test (drift-demo)

> **Not a workshop section.** This lives under `labs/fixtures/` and exists only
> to exercise `scripts/verify.sh`'s annotated-block drift enforcement. See
> AGENT.md · "Lab workdir & drift contract" for the carve-out.

| | |
| --- | --- |
| **Purpose** | verify.sh drift self-test fixture |
| **Environment** | `mock ✓` — no Docker, no cloud; the config is provider-free |

## Objective

Demonstrate the enforced slide↔lab drift lane: the fenced `hcl` block below is
**annotated with its source path**, so `scripts/verify.sh` diffs it against the
tracked file and fails the build if the two drift apart.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.

## Files used

- `labs/fixtures/drift-demo/main.tf` — a self-contained, provider-free config.

## Step 1 — Read the manifest

The block below is the exact content of the tracked file. The HTML comment
immediately above the fence ties the block to its source; drift fails `task verify`.

<!-- source: labs/fixtures/drift-demo/main.tf -->
```hcl
# labs/fixtures/drift-demo/main.tf — reference workdir for the slide↔lab drift lane.
# A self-contained, provider-free config so `tofu fmt`/`validate` run offline.
terraform {
  required_version = ">= 1.8"
}

locals {
  greeting = "hello, opentofu"
}

output "greeting" {
  value = local.greeting
}
```

## Expected observations

- `task verify` diffs this block against `labs/fixtures/drift-demo/main.tf`.
- Editing either side without the other makes the drift check fail, naming the file.

## Cleanup / panic reset

Nothing is applied, so there is nothing to tear down:

```bash
rm -rf labs/fixtures/drift-demo/.terraform labs/fixtures/drift-demo/.terraform.lock.hcl
```
