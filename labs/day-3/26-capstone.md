# Lab 26 — Capstone & wrap-up

| | |
| --- | --- |
| **Section** | S26 — Capstone & wrap-up *(red line: author → protect → test → scale)* |
| **Environment** | `localstack ✓` · `mock ✓` — Steps 1–4 need neither Docker nor cloud; Steps 5–6 use LocalStack |
| **Estimated time** | 60 min (consume track, Steps 1–6) · Part B build variant: **+40 min, stretch / homework — not in the timed budget** |

## Objective

Drive the shipped **US-X-CAP** artifact
[`examples/capstone/`](../../examples/capstone/) to a green unit lane
(`task verify` / filtered `tofu test`), apply it against LocalStack, then
**fully clean up**. Prove a **panic reset** from a half-applied colony leaves
no residue. Do **not** rewrite the capstone — consume it. Then, if you opt into
[Part B (build variant)](#part-b--build-variant-author-the-colonys-4th-resource-stretch--homework-40-min),
**author** the colony's 4th resource yourself from a spec — judged by the same
gates, on your own time.

## Prerequisites

- OpenTofu ≥ 1.9 (`tofu version`). Spoilers captured on **1.12.3** (Part B
  spoilers on **1.12.5**).
- Docker with Compose v2 for Steps 5–6 (`docker compose version`).
- Ports `4566` free (or LocalStack already healthy from earlier labs).
- A shell at the workshop repository root.
- No cloud account or real AWS credentials.

## Files used

All shipped — you consume them:

- [`examples/capstone/`](../../examples/capstone/) — LocalStack multi-module root
  (naming + labels + S3 / DynamoDB / SQS + PBKDF2 encryption + tests).
- [`examples/capstone/tests/unit.tftest.hcl`](../../examples/capstone/tests/unit.tftest.hcl)
  — plan + aliased `mock_provider` (covered by `task verify`).
- [`examples/capstone/tests/integration.tftest.hcl`](../../examples/capstone/tests/integration.tftest.hcl)
  — apply against LocalStack (`task verify:integration`).
- [`examples/capstone/stretch/`](../../examples/capstone/stretch/) — optional
  Terramate pointer (not required for core).
- [`examples/capstone-build/`](../../examples/capstone-build/) — **Part B only**:
  tracked reference implementation of the build variant (peek only after your
  gates are green).

Encryption contract (tracked — drift-checked):

<!-- source: examples/capstone/providers.tf -->
```hcl
# =============================================================================
# examples/capstone — providers + PBKDF2 state encryption
# -----------------------------------------------------------------------------
# Ties Day 1 (S05 encryption, S08 naming/labels) to Day 2 (tofu test) on one
# LocalStack root. Terramate orchestration is a stretch — see stretch/README.md.
# =============================================================================

terraform {
  required_version = ">= 1.8.0" # 1.8+ for mock_provider in tests

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # < 6.0: provider v6's DynamoDB waiter is incompatible with LocalStack
      # community (last release 4.9.2) — apply hangs on "waiting for update …
      # couldn't find resource" despite DescribeTable => 200. v5 applies clean.
      version = ">= 5.0, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }

  # ---------------------------------------------------------------------------
  # STATE ENCRYPTION (OpenTofu native) — S05 ↔ capstone.
  #
  # PBKDF2 derives an AES-GCM key from a passphrase (>= 16 chars). Supply it
  # out-of-band:
  #
  #     export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
  #
  # `enforced = true` (commented) refuses unencrypted state — flip on once
  # every collaborator has the passphrase.
  # ---------------------------------------------------------------------------
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "encrypted" {
      keys = key_provider.pbkdf2.passphrase
    }

    state {
      method = method.aes_gcm.encrypted
      # enforced = true
    }

    plan {
      method = method.aes_gcm.encrypted
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  s3_use_path_style = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3       = "http://localhost:4566"
      dynamodb = "http://localhost:4566"
      sqs      = "http://localhost:4566"
    }
  }
}
```

Colony composition (tracked — drift-checked):

<!-- source: examples/capstone/main.tf -->
```hcl
# =============================================================================
# examples/capstone — settled-colony LocalStack root
# -----------------------------------------------------------------------------
# Composes modules/naming + modules/labels into a small three-resource estate:
#   • S3 bucket     — artifact store
#   • DynamoDB table — metadata index
#   • SQS queue     — async work queue
#
# Base path: plain `tofu` (no Terramate required). Stretch orchestration lives
# under stretch/ and is documented there.
# =============================================================================

# --- Names --------------------------------------------------------------------

module "artifacts_name" {
  source = "../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = var.project
  environment   = var.environment
  description   = "artifacts"
  suffix        = var.artifacts_suffix
}

module "index_name" {
  source = "../../modules/naming"

  resource_type = "aws_dynamodb_table"
  project       = var.project
  environment   = var.environment
  description   = "index"
  suffix        = var.index_suffix
}

module "queue_name" {
  source = "../../modules/naming"

  resource_type = "aws_sqs_queue"
  project       = var.project
  environment   = var.environment
  description   = "work"
  suffix        = var.queue_suffix
}

# --- Shared labels ------------------------------------------------------------

module "labels" {
  source = "../../modules/labels"

  environment = var.environment
  criticality = "medium"
  project     = var.project
  service     = "colony"
  owner       = var.owner
  cost_center = var.cost_center

  data_classification = "internal"
  iac_source_url      = "https://git.example.com/infra/capstone"
}

# --- Resources ----------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket = module.artifacts_name.name
  tags   = module.labels.tags
}

resource "aws_dynamodb_table" "index" {
  name         = module.index_name.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = module.labels.tags
}

resource "aws_sqs_queue" "work" {
  name = module.queue_name.name
  tags = module.labels.tags
}

# --- Guardrail (S15 tie-in) ---------------------------------------------------

check "colony_labels_complete" {
  assert {
    condition = alltrue([
      for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
      contains(keys(module.labels.labels), k)
    ])
    error_message = "capstone label map is missing one or more required taxonomy keys"
  }
}
```

---

## Step 1 — Tour the settled colony

From the repository root, skim the README and list the root files:

```bash
sed -n '1,40p' examples/capstone/README.md
ls examples/capstone/
```

**Task:** Name the four Day-1/Day-2 threads this root ties together, and which
Day-3 piece is **stretch only**.

<details><summary>Solution</summary>

1. **Naming** — `modules/naming` compose S3 / DynamoDB / SQS names.
2. **Labels** — one shared `modules/labels` tag map on every resource.
3. **Encryption** — PBKDF2 → AES-GCM on state and plan (`providers.tf`).
4. **Tests** — unit (mock plan) + integration (LocalStack apply).

**Stretch only:** Terramate under `examples/capstone/stretch/` — base path is
plain `tofu`; `task verify` must stay green with Terramate absent.

</details>

---

## Step 2 — Break → fix: short passphrase

The encryption key provider requires a passphrase ≥ 16 characters. Feed it a
short one and plan:

```bash
tofu -chdir=examples/capstone init -backend=false -no-color
tofu -chdir=examples/capstone plan -var 'state_passphrase=short' -no-color
```

**Task:** What error do you get, and which layer fired?

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

**Fix:** export a workshop-length passphrase and confirm the unit lane plans:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone plan -no-color
```

<details><summary>Expected observation</summary>

Plan proceeds and shows **6 to add** (3× `random_id` + S3 + DynamoDB + SQS)
when suffixes are unset. Names stay `(known after apply)` until the random
suffix resolves. No LocalStack required for this plan.

</details>

---

## Step 3 — Unit lane green (no Docker)

Run the capstone unit filter — aliased `mock_provider`, no cloud:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone test -filter=tests/unit.tftest.hcl -no-color
```

> Prefer the whole workshop unit gate when you have time:
> `task verify` (fmt + validate + plan/mock tests + slide↔lab drift).

**Task:** Which assertions prove naming is wired without needing LocalStack?

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

## Step 4 — Optional naming break (mock path)

Confirm the naming module still rejects a too-short project through the
capstone call sites:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone plan -var 'project=ab' -no-color
```

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

## Step 5 — Apply on LocalStack

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

Run the integration filter (optional if time is short; required for the full
proof):

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone test -filter=tests/integration.tftest.hcl -no-color
```

<details><summary>Expected output</summary>

```console
tests/integration.tftest.hcl... pass
  run "localstack_apply"... pass

Success! 1 passed, 0 failed.
```

Or via Taskfile: `task verify:integration` after `task lab:up`.

</details>

---

## Step 6 — Cleanup + panic reset (no residue)

### Normal cleanup

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone destroy -auto-approve -no-color
task lab:down
```

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

<details><summary>Verify empty residue</summary>

```bash
ls examples/capstone/*.tfstate* 2>/dev/null || echo "no local state — clean"
curl -sf http://localhost:4566/_localstack/health | head -c 120
```

After `lab:down`, `:4566` should refuse connections until the next `lab:up`.

</details>

---

## Expected observations

- Capstone plans with an **aliased `mock_provider`** — no Docker for the unit lane.
- A passphrase shorter than 16 characters fails at the **PBKDF2 key provider**.
- Unit tests assert **fixed-suffix** names + the shared label taxonomy.
- Apply creates `s3-colony-d-artifacts-<hex>`, `ddb-colony-d-index-<hex>`,
  `sqs-colony-d-work-<hex>` with one tag map.
- State is **encrypted at rest**; passphrase is out-of-band (`TF_VAR_…`).
- Panic reset (`destroy` + delete state + `task lab:down`) leaves **no residue**.

## Part B — build variant: author the colony's 4th resource (stretch / homework, ~40 min)

Steps 1–6 had you **consume** the shipped colony. Part B flips the contract:
you **author** the extension yourself, from a spec, and the *same* gates that
judge the shipped code judge yours. It is deliberately **outside the 60-minute
timed budget** — run it as homework, or in-room only when the day is ahead of
schedule. The default consume track above stays the timed-delivery default.

There is no output to copy: acceptance is **gate-green, not byte-matching**.
Be honest about what that means: the gates check *values*, not provenance — a
hardcoded name that happens to equal the composed one, or a hand-typed
seven-key tags map, still greens them — so gate-green is a self-assessment,
not a proctored proof.
One valid implementation is tracked at
[`examples/capstone-build/`](../../examples/capstone-build/) — compare with it
only *after* your gates pass.

### The contract

Create exactly two new files in your working copy (both are new/untracked, so
cleanup is a plain `rm` — no tracked file changes):

| File you author | Must satisfy |
| --- | --- |
| `examples/capstone/colony_events.tf` | An `aws_sns_topic` "events" resource that becomes the colony's 4th resource |
| `examples/capstone/tests/build.tftest.hcl` | A unit test proving the contract at **plan**, no Docker |

The extension contract, point by point:

1. **Composed naming, no literals** — the topic name comes from a new
   `module "events_name"` call to [`modules/naming`](../../modules/naming)
   (`resource_type = "aws_sns_topic"`, `description = "events"`), so it lands as
   `sns-colony-d-events-<suffix>`. Declare an `events_suffix` variable
   (default `null` → random 4-hex) mirroring the three existing suffix
   variables.
2. **Shared labels, one taxonomy** — `tags = module.labels.tags`, reusing the
   colony's *existing* labels instance. Do not instantiate a second labels
   module and do not hand-write a tags map.
3. **An output** — `events_topic_name`, mirroring the three existing name
   outputs.
4. **A guardrail** — a `check "events_labels_complete"` block asserting the
   required taxonomy keys on `aws_sns_topic.events.tags`, in the style of the
   root's `colony_labels_complete`.
5. **A unit test** — `plan` + aliased `mock_provider "aws"` (mirror
   `tests/unit.tftest.hcl`), a **fixed** `events_suffix` so the composed name is
   known at plan, and at least: the composed-name assertion, a
   name-comes-from-the-module assertion, and a taxonomy-keys assertion.

> **Why SNS, and why no apply?** `aws_sns_topic` is already in the naming
> module's short-name profile (`sns`), and LocalStack community supports it —
> but the capstone's provider `endpoints` block deliberately routes only
> `s3`/`dynamodb`/`sqs`. Part B is therefore a **mock-only** lane: validate +
> `tofu test` with a mocked provider, no Docker, no LocalStack. That is the
> point — the unit gates alone can judge an authored extension.

### B1 — author `colony_events.tf`

Write `examples/capstone/colony_events.tf` against contract points 1–4. A
`variable` block may live in any `.tf` file, so the whole extension —
variable, module call, resource, output, check — fits in this one file and
never touches the tracked `variables.tf`/`main.tf`.

<details><summary>One valid implementation (byte-identical to the tracked reference)</summary>

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

</details>

### B2 — author `tests/build.tftest.hcl`

Write `examples/capstone/tests/build.tftest.hcl` against contract point 5.
Look at how `tests/unit.tftest.hcl` pins `artifacts_suffix = "a1b2"` — your
test needs the same trick for `events_suffix`, or names stay
`(known after apply)` and your assertions cannot evaluate at plan.

<details><summary>One valid implementation (byte-identical to the tracked reference)</summary>

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

</details>

### B3 — judge it with the existing gates

First, one **mandatory re-init**: your new `module "events_name"` call is not
in the module manifest that the Step 2 init wrote, so `validate` and
`tofu test` refuse with `Error: Module not installed` until you re-run init
(that is Failure 1 in the B4 gallery). After that, no new gate machinery: the
commands that judged the shipped colony judge your extension. From the repo
root:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/capstone init -backend=false -no-color
tofu -chdir=examples/capstone fmt -check -diff
tofu -chdir=examples/capstone validate -no-color
tofu -chdir=examples/capstone test -filter=tests/build.tftest.hcl -no-color
tofu -chdir=examples/capstone test -filter=tests/unit.tftest.hcl -filter=tests/encryption.tftest.hcl -no-color
```

The last command proves your extension did not break the shipped contracts —
the colony's own unit + encryption tests must stay green with your files in
place. (`task verify` also picks your files up automatically: its sweep
validates every root by filesystem, and runs every non-integration
`*.tftest.hcl` it finds — including yours.)

**Task:** the re-init plus all four gate commands green, plus one
observation — what does `tofu -chdir=examples/capstone plan -no-color` count
now?

<details><summary>Solution / expected output</summary>

Spoilers captured on OpenTofu **1.12.5**:

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

And the plan grows from **6 to add** to **8 to add** — your topic plus its
naming module's `random_id`:

```console
Plan: 8 to add, 0 to change, 0 to destroy.
```

`fmt -check` and `validate` print nothing / `Success!` respectively.

</details>

### B4 — break → fix gallery: the four likely failures

Each failure below is the gate doing its job — the diagnosis *is* the teaching
moment. Reproduce any you did not hit naturally.

**Failure 1 — gates run against the old init: `Module not installed`**: you
authored `module "events_name"` but skipped the B3 re-init, so `validate` and
`tofu test` refuse before judging anything — every learner hits this once.

<details><summary>Diagnosis / fix</summary>

```console
$ tofu -chdir=examples/capstone validate -no-color

Error: Module not installed

  on colony_events.tf line 19:
  19: module "events_name" {

This module is not yet installed. Run "tofu init" to install all modules
required by this configuration.
```

**Fix:** `tofu -chdir=examples/capstone init -backend=false -no-color` — a
`module` call is resolved at init, not at plan, so every new or changed
`module` block needs a re-init before any command that loads the
configuration. The error names its own fix.

</details>

**Failure 2 — a `resource_type` the naming profile does not know** (e.g. you
typo `aws_ssm_parameter`): the naming module's output precondition refuses to
compose a name.

<details><summary>Diagnosis / fix</summary>

```console
Error: Module output value precondition failed

  on ../../modules/naming/outputs.tf line 14, in output "name":
  14:     condition     = contains(keys(var.resource_short_names), var.resource_type)
    ├────────────────
    │ var.resource_short_names is map of string with 20 elements
    │ var.resource_type is "aws_ssm_parameter"

resource_type "aws_ssm_parameter" is not in resource_short_names. Add it to
the profile or pass a map override.
```

**Fix:** use `resource_type = "aws_sns_topic"` — it is already in the profile
(short code `sns`). The S08 lesson: the module fails closed on unknown types
instead of silently composing a junk name.

</details>

**Failure 3 — no fixed suffix in the test**: leave `events_suffix` unset and
the name is `(known after apply)`, so plan-time assertions cannot evaluate.

<details><summary>Diagnosis / fix</summary>

```console
Error: Unknown condition run

  on tests/build.tftest.hcl line 23, in run "build_unit_plan":
  23:     condition     = module.events_name.name == "sns-colony-d-events-f7a9"
    ├────────────────
    │ module.events_name.name is a string

Condition expression could not be evaluated at this time.

Error: Unknown condition run

  on tests/build.tftest.hcl line 28, in run "build_unit_plan":
  28:     condition     = aws_sns_topic.events.name == module.events_name.name
    ├────────────────
    │ aws_sns_topic.events.name is a string
    │ module.events_name.name is a string

Condition expression could not be evaluated at this time.

Failure! 0 passed, 1 failed.
```

Both plan-time name assertions go unknown at once; the taxonomy assertions
still evaluate, because the mocked tags map is plan-known.

**Fix:** pin `events_suffix = "f7a9"` (any 2–8 lowercase alphanumerics) in the
run's `variables` block — the same reason `tests/unit.tftest.hcl` pins
`a1b2`/`c3d4`/`e5f6`. Random suffixes are for apply; fixed suffixes make names
plan-known.

</details>

**Failure 4 — a hand-written `tags` literal instead of `module.labels.tags`**:
your own guardrail catches the taxonomy hole during `tofu test`.

<details><summary>Diagnosis / fix</summary>

```console
Error: Check block assertion failed

  on colony_events.tf line 44, in check "events_labels_complete":
  44:     condition = alltrue([
  45:       for k in ["environment", "criticality", "project", "service", "owner", "cost-center"] :
  46:       contains(keys(aws_sns_topic.events.tags), k)
  47:     ])
    ├────────────────
    │ aws_sns_topic.events.tags is map of string with 2 elements

events topic is missing one or more required taxonomy keys

Failure! 0 passed, 1 failed.
```

**Fix:** `tags = module.labels.tags`. Note the layering: in a plain
`tofu plan`, a failing `check` is only a warning — but inside `tofu test` it
fails the run. Your test is what gives the guardrail teeth.

</details>

### B5 — cleanup: leave the tree porcelain-clean

Both Part B files are new and untracked, so cleanup is a plain remove — no
tracked file was ever modified:

```bash
rm -f examples/capstone/colony_events.tf examples/capstone/tests/build.tftest.hcl
git status --porcelain -- examples/capstone
```

<details><summary>Expected observation</summary>

`git status --porcelain -- examples/capstone` prints **nothing** — the tracked
colony (including `examples/capstone/.terraform.lock.hcl`) is untouched. The
Step 6 panic reset still applies unchanged if you also applied/planned along
the way.

</details>

---

## Stretch (optional)

- Read [`examples/capstone/stretch/README.md`](../../examples/capstone/stretch/README.md)
  and sketch a `storage` / `messaging` Terramate split — do **not** move the
  base root unless you keep a Terramate-free path for `task verify`.
- Flip `enforced = true` in `providers.tf`, drop the passphrase, and watch
  OpenTofu refuse plaintext state (restore the comment afterward — do not commit
  the flip).
