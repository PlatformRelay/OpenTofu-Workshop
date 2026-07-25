# Lab 26 — Capstone & wrap-up

| | |
| --- | --- |
| **Section** | S26 — Capstone & wrap-up *(red line: author → protect → test → scale)* |
| **Environment** | `localstack ✓` · `mock ✓` — Steps 1–4 need neither Docker nor cloud; Steps 5–6 use LocalStack |
| **Estimated time** | 60 min |

## Objective

Drive the shipped **US-X-CAP** artifact
[`examples/capstone/`](../../examples/capstone/) to a green unit lane
(`task verify` / filtered `tofu test`), apply it against LocalStack, then
**fully clean up**. Prove a **panic reset** from a half-applied colony leaves
no residue. Do **not** rewrite the capstone — consume it.

## Prerequisites

- OpenTofu ≥ 1.8 (`tofu version`). Spoilers captured on **1.12.3**.
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

## Stretch (optional)

- Read [`examples/capstone/stretch/README.md`](../../examples/capstone/stretch/README.md)
  and sketch a `storage` / `messaging` Terramate split — do **not** move the
  base root unless you keep a Terramate-free path for `task verify`.
- Flip `enforced = true` in `providers.tf`, drop the passphrase, and watch
  OpenTofu refuse plaintext state (restore the comment afterward — do not commit
  the flip).
