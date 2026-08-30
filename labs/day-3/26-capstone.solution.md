# Lab 26 — Capstone & wrap-up — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the repository root; the tracked capstone workdir is `examples/capstone/`
and every command below targets it with `tofu -chdir=examples/capstone` or explicit
paths, so no `cd` is needed.

### Step 1 — Tour the settled colony

From the repository root, skim the README and list the root files:

```bash
sed -n '1,40p' examples/capstone/README.md
ls examples/capstone/
```

**Task:** Name the four Day-1/Day-2 threads this root ties together, and which
Day-3 piece is **stretch only**.

---

<details><summary>Solution</summary>

1. **Naming** — `modules/naming` compose S3 / DynamoDB / SQS names.
2. **Labels** — one shared `modules/labels` tag map on every resource.
3. **Encryption** — PBKDF2 → AES-GCM on state and plan (`providers.tf`).
4. **Tests** — unit (mock plan) + integration (LocalStack apply).

**Stretch only:** Terramate under `examples/capstone/stretch/` — base path is
plain `tofu`; `task verify` must stay green with Terramate absent.

</details>

---

### Step 2 — Break → fix: short passphrase

The encryption key provider requires a passphrase ≥ 16 characters. Feed it a
short one and plan:

```bash
tofu -chdir=examples/capstone init -backend=false -no-color
tofu -chdir=examples/capstone plan -var 'state_passphrase=short' -no-color
```

**Task:** What error do you get, and which layer fired?

**Fix:** export a workshop-length passphrase and confirm the unit lane plans:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone plan -no-color
```

---

<details><summary>Solution / expected output</summary>

Spoilers captured on OpenTofu **1.12.3**:

```console
Error: Unable to build encryption key data

key_provider.pbkdf2.passphrase failed with error: passphrase is too short
(minimum 16 characters)
```

The **PBKDF2 key provider** rejected the passphrase before a plan could build.
(You may also see the variable validation on `state_passphrase` fire when the
value is supplied as a root variable — both insist on ≥ 16 characters.)

</details>

<details><summary>Expected observation</summary>

Plan proceeds and shows **6 to add** (3× `random_id` + S3 + DynamoDB + SQS)
when suffixes are unset. Names stay `(known after apply)` until the random
suffix resolves. No LocalStack required for this plan.

</details>

---

### Step 3 — Unit lane green (no Docker)

Run the capstone unit filter — aliased `mock_provider`, no cloud:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone test -filter=tests/unit.tftest.hcl -no-color
```

> Prefer the whole workshop unit gate when you have time:
> `task verify` (fmt + validate + plan/mock tests + slide↔lab drift).

**Task:** Which assertions prove naming is wired without needing LocalStack?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu -chdir=examples/capstone test -filter=tests/unit.tftest.hcl -no-color
tests/unit.tftest.hcl... pass
  run "unit_plan_with_mock"... pass

Success! 1 passed, 0 failed.
```

Fixed suffixes in the unit run make composed names known at plan:

- `s3-colony-d-artifacts-a1b2`
- `ddb-colony-d-index-c3d4`
- `sqs-colony-d-work-e5f6`

plus the required label keys (`project`, `environment`, `service`, …) and
`managed-by = opentofu`.

</details>

---

### Step 4 — Optional naming break (mock path)

Confirm the naming module still rejects a too-short project through the
capstone call sites:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone plan -var 'project=ab' -no-color
```

---

<details><summary>Solution / expected output</summary>

```console
Error: Invalid value for variable

  on main.tf line 19, in module "artifacts_name":
  19:   project       = var.project

project must be 4-10 chars, lowercase letters/digits, starting with a letter.
```

You get one diagnostic per naming call site (`artifacts_name`, `index_name`,
`queue_name`) — same S08 contract, three consumers.

</details>

---

### Step 5 — Apply on LocalStack

Bring up LocalStack (skip if already healthy) and apply:

```bash
task lab:up
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone apply -auto-approve -no-color
tofu -chdir=examples/capstone output -no-color
```

> `task lab:apply DIR=examples/capstone` runs interactive `tofu apply` (asks
> for `yes`). Prefer `-auto-approve` in this lab so the step is non-interactive.

**Task:** Show the three composed names and that labels share one taxonomy.

Run the integration filter (optional if time is short; required for the full
proof):

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone test -filter=tests/integration.tftest.hcl -no-color
```

---

<details><summary>Solution / expected output</summary>

Shape from OpenTofu **1.12.3** + LocalStack **4.9.2** (hex suffixes vary):

```console
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

artifacts_bucket_name = "s3-colony-d-artifacts-09d9"
index_table_name = "ddb-colony-d-index-cce6"
labels = {
  "cost-center" = "CC-2600"
  "criticality" = "medium"
  "data-classification" = "internal"
  "environment" = "dev"
  "iac-source-url" = "https://git.example.com/infra/capstone"
  "managed-by" = "opentofu"
  "owner" = "platform-team@example.com"
  "project" = "colony"
  "service" = "colony"
}
work_queue_name = "sqs-colony-d-work-88bb"
```

SQS create can take ~20–30 s on LocalStack — wait for `Creation complete`.

</details>

<details><summary>Expected output</summary>

```console
tests/integration.tftest.hcl... pass
  run "localstack_apply"... pass

Success! 1 passed, 0 failed.
```

Or via Taskfile: `task verify:integration` after `task lab:up`.

</details>

---

### Step 6 — Cleanup + panic reset (no residue)

### Normal cleanup

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone destroy -auto-approve -no-color
task lab:down
```

### Panic reset — half-applied colony

Use when apply died mid-run, LocalStack crashed, or the room needs a clean
slate in ≤5 minutes:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
# Best effort — ignore failures if state/emulator is already gone
tofu -chdir=examples/capstone destroy -auto-approve -no-color || true
rm -f examples/capstone/*.tfstate examples/capstone/*.tfstate.*
task lab:down
task lab:up          # only if the class continues on LocalStack
```

**Edge criterion:** after panic reset, the capstone root has **no** local state
files and LocalStack (if restarted) has **no** leftover colony resources from
the half-apply. Nothing was created on real AWS.

---

### Part B — build variant: author the colony's 4th resource (stretch / homework)

Part B is assessed by gates, not by matching bytes — any implementation that
satisfies the contract and greens the commands below is correct. The tracked
reference lives at [`examples/capstone-build/`](../../examples/capstone-build/);
its two drop-in files are reproduced here byte-identically (drift-checked).

`examples/capstone/colony_events.tf` — one valid implementation:

<!-- source: examples/capstone-build/colony_events.tf -->
```hcl
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
```

`examples/capstone/tests/build.tftest.hcl` — one valid implementation:

<!-- source: examples/capstone-build/tests/build.tftest.hcl -->
```hcl
# =============================================================================
# capstone BUILD VARIANT — unit test for the events topic (no cloud, no Docker)
# -----------------------------------------------------------------------------
# command = plan + ALIASED mock_provider "aws", mirroring the capstone's
# tests/unit.tftest.hcl. A FIXED events_suffix makes the composed topic name
# known at plan, so the naming contract is asserted without an apply. Drop-in
# for examples/capstone/tests/ — it only references addresses that exist in
# both roots (module.events_name, aws_sns_topic.events, the shared labels).
# =============================================================================

mock_provider "aws" { alias = "mock" }

run "build_unit_plan" {
  command   = plan
  providers = { aws = aws.mock }

  variables {
    project       = "colony"
    environment   = "dev"
    events_suffix = "f7a9"
  }

  assert {
    condition     = module.events_name.name == "sns-colony-d-events-f7a9"
    error_message = "events topic name should be sns-colony-d-events-f7a9"
  }

  assert {
    condition     = aws_sns_topic.events.name == module.events_name.name
    error_message = "the topic name must match the naming module's composed output"
  }

  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(aws_sns_topic.events.tags), k)
    ])
    error_message = "events topic tags must carry the full shared label taxonomy"
  }

  assert {
    condition     = aws_sns_topic.events.tags["managed-by"] == "opentofu"
    error_message = "events topic should inherit managed-by = opentofu from the shared labels"
  }
}
```

Assessment commands and their green output (captured on OpenTofu **1.12.5**).
The re-init comes first — the new `module "events_name"` call is not in the
module manifest of the previous init, and `validate`/`tofu test` fail with
`Error: Module not installed` without it:

```console
$ tofu -chdir=examples/capstone init -backend=false -no-color
Initializing modules...
- events_name in ../../modules/naming

Initializing provider plugins...
- Reusing previous version of hashicorp/random from the dependency lock file
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/random v3.9.0
- Using previously-installed hashicorp/aws v5.100.0

OpenTofu has been successfully initialized!

You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure. All OpenTofu commands
should now work.

If you ever set or change modules or backend configuration for OpenTofu,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

$ tofu -chdir=examples/capstone fmt -check -diff
$ tofu -chdir=examples/capstone validate -no-color
Success! The configuration is valid.

$ tofu -chdir=examples/capstone test -filter=tests/build.tftest.hcl -no-color
tests/build.tftest.hcl... pass
  run "build_unit_plan"... pass

Success! 1 passed, 0 failed.

$ tofu -chdir=examples/capstone test -filter=tests/unit.tftest.hcl -filter=tests/encryption.tftest.hcl -no-color
tests/encryption.tftest.hcl... pass
  run "encryption_contract_plan"... pass
  run "state_passphrase_too_short_rejected"... pass
tests/unit.tftest.hcl... pass
  run "unit_plan_with_mock"... pass

Success! 3 passed, 0 failed.
```

With the extension in place `tofu -chdir=examples/capstone plan` reports
**8 to add** (the shipped 6, plus your topic and its naming `random_id`).
The four likely failure modes and their real diagnoses (skipped re-init →
`Error: Module not installed` from `validate`/`tofu test`; unknown
`resource_type` → naming-module precondition; unset `events_suffix` → two
`Unknown condition run` errors at plan; hand-written `tags` literal →
`Check block assertion failed` in `tofu test`) are spoilered in the lab's
Part B gallery — the fix for each is in the contract itself or in the B3
command list.

Cleanup is a plain remove, because both authored files are untracked:

```bash
rm -f examples/capstone/colony_events.tf examples/capstone/tests/build.tftest.hcl
git status --porcelain -- examples/capstone
```

`git status --porcelain` prints nothing afterward — no tracked file (including
`examples/capstone/.terraform.lock.hcl`) was ever modified.

---

## Expected observations

- Capstone plans with an **aliased `mock_provider`** — no Docker for the unit lane.
- A passphrase shorter than 16 characters fails at the **PBKDF2 key provider**.
- Unit tests assert **fixed-suffix** names + the shared label taxonomy.
- Apply creates `s3-colony-d-artifacts-<hex>`, `ddb-colony-d-index-<hex>`,
  `sqs-colony-d-work-<hex>` with one tag map.
- State is **encrypted at rest**; passphrase is out-of-band (`TF_VAR_…`).
- Panic reset (`destroy` + delete state + `task lab:down`) leaves **no residue**.

## Stretch (optional)

- Read [`examples/capstone/stretch/README.md`](../../examples/capstone/stretch/README.md)
  and sketch a `storage` / `messaging` Terramate split — do **not** move the
  base root unless you keep a Terramate-free path for `task verify`.
- Flip `enforced = true` in `providers.tf`, drop the passphrase, and watch
  OpenTofu refuse plaintext state (restore the comment afterward — do not commit
  the flip).

<details><summary>Expected observation</summary>

```console
Destroy complete! Resources: 6 destroyed.
```

`PERSISTENCE=0` means LocalStack volumes are a clean slate after `lab:down`.
Local OpenTofu state files under the capstone root are gitignored — remove any
leftover `*.tfstate*` if a prior crash left them:

```bash
rm -f examples/capstone/*.tfstate examples/capstone/*.tfstate.*
```

</details>

<details><summary>Verify empty residue</summary>

```bash
ls examples/capstone/*.tfstate* 2>/dev/null || echo "no local state — clean"
curl -sf http://localhost:4566/_localstack/health | head -c 120
```

After `lab:down`, `:4566` should refuse connections until the next `lab:up`.

</details>

---

## Expected state / output

- Capstone plans with an **aliased `mock_provider`** — no Docker for the unit lane.
- A passphrase shorter than 16 characters fails at the **PBKDF2 key provider**.
- Unit tests assert **fixed-suffix** names + the shared label taxonomy.
- Apply creates `s3-colony-d-artifacts-<hex>`, `ddb-colony-d-index-<hex>`,
  `sqs-colony-d-work-<hex>` with one tag map.
- State is **encrypted at rest**; passphrase is out-of-band (`TF_VAR_…`).
- Panic reset (`destroy` + delete state + `task lab:down`) leaves **no residue**.

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

OpenTofu reconciles declared configuration against stored state on every plan and
apply, so the commands above succeed only when the tracked HCL, provider plugins,
and backend settings match what the lab authored. Each step therefore wires inputs
(outputs, variables, modules, or data sources) before the resources that consume
them, because the graph must be acyclic at evaluation time.

When a step reads remote or emulated cloud APIs (LocalStack or mock providers), the
provider block binds credentials and endpoints first; resources then call those APIs
and persist returned attributes into state. That is why init/plan/apply ordering
matters and why re-running apply without changes reports zero additions.

## Troubleshooting and recovery

If a step fails mid-lab, reset generated artifacts and retry:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
# Best effort — ignore failures if state/emulator is already gone
tofu -chdir=examples/capstone destroy -auto-approve -no-color || true
rm -rf examples/capstone/.terraform
rm -f examples/capstone/*.tfstate examples/capstone/*.tfstate.*
```

The tracked `examples/capstone/.terraform.lock.hcl` stays put — it pins provider
versions and must survive a reset. Replay from the failing step (every command runs
from the repo root). For provider errors, run `tofu -chdir=examples/capstone init`
and retry `tofu -chdir=examples/capstone plan`.

## Stretch solution

### Commands / manifest

- Read [`examples/capstone/stretch/README.md`](../../examples/capstone/stretch/README.md)
- Flip `enforced = true` in `providers.tf`, drop the passphrase, and watch

Example verification from the repo root:

```bash
tofu -chdir=examples/capstone plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
