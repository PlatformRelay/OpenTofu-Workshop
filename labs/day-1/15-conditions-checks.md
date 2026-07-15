# Lab 15 — Preconditions, postconditions & check blocks (S15)

| | |
| --- | --- |
| **Section** | S15 — Validation, pre/postconditions & check blocks *(red line: author → parameterize → **guard**)* |
| **Environment** | `mock ✓ (no docker)` — pure-local `local` + `random` providers; no cloud, no LocalStack |
| **Estimated time** | 30 min |

## Objective

You already gave the config a typed, validated interface in Lab 06. Now layer
**assertions** onto it and learn *which phase each one fires in*:

- a **lifecycle `precondition`** and an **output `precondition`** — evaluated at
  **plan**, they block before anything is built;
- a **lifecycle `postcondition`** — evaluated at **apply**, it guards the result
  *after* the resource is created;
- a **non-blocking `check` block** — evaluated at plan **and** apply, it emits a
  **warning** and never fails the run.

The payoff is the **break → fix**: trip the postcondition on apply, read the
diagnostic line-by-line, then fix it. You run **tracked files**, not heredocs —
what you apply is exactly what CI verified. The config lives at
`labs/day-1/15-conditions-checks/`:

- `main.tf` — the S06 `service` object carried forward, now driving a
  `local_file` guarded by a `precondition` + `postcondition`, an `output`
  precondition, and a `check` block. This is the exact HCL the lab applies; the
  slide and this file are drift-checked to stay byte-identical.
- `terraform.tfvars` — the auto-loaded `staging` / `replicas = 2` baseline; the
  Steps override individual values with `-var`.

## Prerequisites

- `tofu` ≥ 1.6 — OpenTofu's first GA — (`task setup` installs it); any current
  `tofu` has all four constructs. The feature lineage traces to Terraform:
  pre/postconditions from 1.2, `check` blocks from 1.5. Check: `tofu version`
  (this lab was verified on `tofu v1.12.3`).
- You have done Lab 06 (S06) — this lab continues from that `service`-object shape.
- Run everything **from the repo clone** — no Docker, no cloud.

## Files used

All tracked in `labs/day-1/15-conditions-checks/` — you run them, you do not paste them:

- `main.tf` — variables, resources, assertions, and the guarded output (below).
- `terraform.tfvars` — the auto-loaded baseline (`staging`, `replicas = 2`).
- `.gitignore` — keeps generated state / `.terraform` / the rendered `out/` file
  out of version control.

This is the config you apply — read it before you run it. Note the **four**
assertion sites and, in the comments, **which phase** each fires in:

<!-- source: labs/day-1/15-conditions-checks/main.tf -->
```hcl
terraform {
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# Carried forward from S06: the typed object that drives the config.
variable "service" {
  description = "The service this config renders a manifest for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}

variable "environment" {
  description = "Deployment environment. Drives the prod output precondition."
  type        = string
  default     = "dev"
}

# The postcondition's budget. Feed a tiny value with -var to break on APPLY.
variable "max_manifest_bytes" {
  description = "Byte ceiling for the rendered manifest, enforced by a postcondition."
  type        = number
  default     = 400
}

# The check's threshold. Feed a value below 16 with -var to trip the WARNING.
variable "min_secret_length" {
  description = "Minimum session-secret length. A non-blocking check warns if it is weak."
  type        = number
  default     = 24
}

# A non-sensitive, known-after-apply value — so the postcondition can read the
# rendered content at apply time without tripping OpenTofu's sensitive-value guard.
resource "random_pet" "release" {
  length = 2
}

# Generated here only to give the check a real threshold to assert on. Its value
# never lands in the manifest, so nothing sensitive leaks into the postcondition.
resource "random_password" "session" {
  length = var.min_secret_length
}

resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    RELEASE=${random_pet.release.id}
  EOT

  lifecycle {
    # precondition: evaluated at PLAN. A false condition blocks the plan before
    # any resource is touched.
    precondition {
      condition     = var.service.replicas >= 1
      error_message = "A service needs at least 1 replica (got ${var.service.replicas})."
    }

    # postcondition: references self.content, which is known-after-apply, so it
    # is evaluated at APPLY — after the file is written. A false condition fails
    # the apply (the resource is already created; only the assertion failed).
    postcondition {
      condition     = length(self.content) <= var.max_manifest_bytes
      error_message = "Rendered manifest is ${length(self.content)} bytes; budget is ${var.max_manifest_bytes}."
    }
  }
}

# An OUTPUT precondition (1.2) — evaluated at PLAN, guarding what we export.
output "manifest_path" {
  description = "Where the rendered manifest landed."
  value       = local_file.manifest.filename

  precondition {
    condition     = var.environment != "prod" || var.service.replicas >= 2
    error_message = "A prod service needs at least 2 replicas (got ${var.service.replicas})."
  }
}

# A check block (1.5) — NON-BLOCKING. Evaluated at plan AND apply; a failed
# assertion emits a WARNING and never fails the run.
check "secret_strength" {
  assert {
    condition     = var.min_secret_length >= 16
    error_message = "Session secret is ${var.min_secret_length} chars; use >= 16 for prod-grade strength."
  }
}
```

> Provider versions and generated IDs (the `random_pet` name, file IDs) in the
> outputs below are from one real run on `tofu v1.12.3` — yours will differ in
> those volatile bits. The **byte count** in Step 4's error also varies with the
> pet name; the point is that it exceeds the budget, not the exact number.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/15-conditions-checks
ls
```

**Task:** Confirm the config files are already present — you author nothing.

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf  terraform.tfvars
```

`main.tf` and `terraform.tfvars` are tracked in the repo. Everything below runs
against these exact files. (`.gitignore` is present too but hidden by `ls`.)
</details>

---

## Step 1 — Init and apply the baseline

```bash
tofu init
tofu apply -auto-approve
```

`terraform.tfvars` is auto-loaded (`environment = "staging"`, `replicas = 2`), so
every assertion is satisfied and the apply succeeds.

**Task:** Apply the good baseline. All four assertions pass silently.

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
random_pet.release: Creating...
random_password.session: Creating...
random_pet.release: Creation complete after 0s [id=pet-imp]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=96112707eaebeadbdd00c340cbdbf089a65605ef]
random_password.session: Creation complete after 0s [id=none]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

manifest_path = "./out/checkout.env"
```

A clean apply: the two preconditions and the output precondition passed at plan,
the postcondition passed at apply, and the `check` passed at both — so you see no
warnings or errors. Every guard is quiet when the config is healthy.
</details>

---

## Step 2 — The `check` block warns — but never blocks

`check` is the odd one out: it is **non-blocking**. Feed a weak
`min_secret_length` and watch it emit a **warning** while the run still succeeds:

```bash
tofu plan -var='min_secret_length=8'
```

**Task:** Does the plan fail? What severity is the `check` output?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='min_secret_length=8'
...
Plan: 1 to add, 0 to change, 1 to destroy.

Warning: Check block assertion failed

  on main.tf line 93, in check "secret_strength":
  93:     condition     = var.min_secret_length >= 16
    ├────────────────
    │ var.min_secret_length is 8

Session secret is 8 chars; use >= 16 for prod-grade strength.
```

The assertion is **`Warning`**, not `Error`, and the plan still produces a valid
result (`Plan: 1 to add … 1 to destroy` — the shorter password forces the
`random_password` to be replaced). A `check` **never** fails the run; it is
advisory. That is exactly why you use it for soft, drift-style signals rather than
hard preconditions. (It warns at **apply** too — same message, and
`Apply complete!` still prints.)
</details>

---

## Step 3 — A `precondition` blocks at PLAN

Contrast with a hard guard. The `local_file`'s lifecycle `precondition` requires
at least one replica. Feed zero and watch the **plan** stop before any resource is
touched:

```bash
tofu plan -var='service={name="checkout",tier="standard",replicas=0}'
```

**Task:** At which phase does this fail — plan or apply? Is anything created?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='service={name="checkout",tier="standard",replicas=0}'

Planning failed. OpenTofu encountered an error while generating this plan.


Error: Resource precondition failed

  on main.tf line 64, in resource "local_file" "manifest":
  64:       condition     = var.service.replicas >= 1
    ├────────────────
    │ var.service.replicas is 0

A service needs at least 1 replica (got 0).
```

A `precondition` is evaluated at **plan** (`Planning failed`), so it fails **before**
anything is built — nothing is created. Preconditions guard the *inputs* to a
resource; use them to reject a bad plan up front. The output `precondition` (Step 6)
behaves the same way — plan-time — because it reads plan-known variables.
</details>

---

## Step 4 — Break the `postcondition` on APPLY (on purpose)

Now the payoff. The `postcondition` reads `self.content` — the rendered file — and
that value is **known-after-apply**, so it is evaluated at **apply**, once the file
already exists. Reset to a clean create, then squeeze the byte budget so the
rendered manifest blows past it:

```bash
tofu destroy -auto-approve      # clean slate so the file is CREATED fresh
tofu apply -auto-approve -var='max_manifest_bytes=10'
```

**Task:** Read the error line by line. What phase is it? Was the file created
before the assertion fired?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve -var='max_manifest_bytes=10'
...
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=258f338084ee56e64f80f6445bccb68c416c876b]
random_password.session: Creation complete after 0s [id=none]

Error: Resource postcondition failed

  on main.tf line 72, in resource "local_file" "manifest":
  72:       condition     = length(self.content) <= var.max_manifest_bytes
    ├────────────────
    │ self.content is "SERVICE_NAME=checkout\nSERVICE_TIER=standard\nREPLICAS=2\nENVIRONMENT=staging\nRELEASE=boss-kitten\n"
    │ var.max_manifest_bytes is 10

Rendered manifest is 95 bytes; budget is 10.
```

Read it top to bottom:

1. `local_file.manifest: Creation complete` — the file **was written first**. A
   postcondition runs *after* the resource is created, so this is genuinely an
   **apply-time** failure, not a plan-time one.
2. `Error: Resource postcondition failed` — severity is `Error` (unlike the
   `check`'s warning), so the apply is marked failed.
3. `on main.tf line 72 … condition = length(self.content) <= var.max_manifest_bytes`
   — the exact assertion that failed.
4. The `self.content is "…"` line dumps the real rendered content, and
   `var.max_manifest_bytes is 10` shows the budget. Your error message
   (`Rendered manifest is 95 bytes; budget is 10.`) does the arithmetic for you.

The byte count (and the `RELEASE=` pet name) vary per run — the point is that the
content exceeds the budget. The resource is now in state; only the assertion failed.
</details>

---

## Step 5 — Fix it

The resource already exists — only the postcondition rejected it. Drop the
artificial budget (or raise it above the real size) and re-apply:

```bash
tofu apply -auto-approve
```

**Task:** Confirm the apply is now clean. Why does it report `0 changed`?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
OpenTofu has compared your real infrastructure against your configuration and
found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

manifest_path = "./out/checkout.env"
```

The default `max_manifest_bytes = 400` easily fits the ~95-byte manifest, so the
postcondition passes. It reports `0 added, 0 changed` because Step 4 **already
created** the file in state before its postcondition failed — the fix only had to
satisfy the assertion, not rebuild anything. That is the tell-tale signature of a
postcondition failure: the resource is real, the guard is what said no.
</details>

---

## Step 6 — The output `precondition` guards what you export

Outputs get preconditions too (1.2) — and they are plan-time, like the lifecycle
one. This rule says a `prod` service must export at least 2 replicas. Break it:

```bash
tofu plan -var='environment=prod' -var='service={name="checkout",tier="standard",replicas=1}'
```

**Task:** Which construct fails, and at which phase?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -var='environment=prod' \
    -var='service={name="checkout",tier="standard",replicas=1}'
...
Plan: 1 to add, 0 to change, 1 to destroy.

Error: Module output value precondition failed

  on main.tf line 84, in output "manifest_path":
  84:     condition     = var.environment != "prod" || var.service.replicas >= 2
    ├────────────────
    │ var.environment is "prod"
    │ var.service.replicas is 1

A prod service needs at least 2 replicas (got 1).
```

`Error: Module output value precondition failed` — an **output** precondition,
failing at **plan**. The diagnostic names both `var.environment` and
`var.service.replicas`, just like S06's cross-variable validation. Use an output
precondition to assert an invariant about a *value you publish*, not just a
resource's inputs.
</details>

## Expected observations

- A **`check` block** is **non-blocking**: it emits a `Warning` at plan **and**
  apply and the run still succeeds (`Apply complete!`). It never errors the run.
- A **`precondition`** (lifecycle or output) fails at **plan** — before anything
  is built.
- A **`postcondition`** fails at **apply** — *after* the resource is created,
  because it reads a known-after-apply value (`self.content`). The fix re-apply
  reports `0 changed`, proving the resource already existed.
- Every diagnostic is read **line by line**: severity, the `on main.tf line N`
  site, the failing `condition`, the referenced values, then your `error_message`.

## Cleanup / panic reset

Destroy the (local-only) resources and remove every generated artifact — no
residue, `git status` clean:

```bash
cd labs/day-1/15-conditions-checks
tofu destroy -auto-approve                                   # tear down local_file + random_*
rm -rf .terraform .terraform.lock.hcl out
find . -maxdepth 1 -name 'terraform.tfstate*' -delete        # sweep any state/backup files safely
git status --short .                                          # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state / `.terraform` / rendered `out/` file are gitignored; the
panic reset leaves the tracked files exactly as CI verified them.

> The `find … -delete` sweep is shell-agnostic: a raw `terraform.tfstate.*` glob
> aborts under zsh's `nomatch` when no such file exists, and `tofu` can leave
> timestamped `.backup` files behind. `find` matches zero-or-more without erroring.

## Stretch (optional)

- Add a **scoped `data` source inside the `check`** — a `check` block can embed
  its own `data` source and assert on it (e.g. poll a health endpoint post-apply).
  Keep it local here; the pattern is what matters. (Real network checks belong in
  a LocalStack/cloud lab, not this no-Docker one.)
- Add a **postcondition to a `data` source** that asserts a fetched value looks
  right — a common pattern for failing fast on a bad upstream.
- Convert the `check`'s soft rule into a hard `precondition` and feel the
  difference: the same bad input now **blocks** instead of warning. When is each
  the right call?
