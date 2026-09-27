# Lab 04 — read and steer state (list / show / mv / rm, drift + a plaintext secret)

| | |
| --- | --- |
| **Section** | S04 — State *(red line: **apply** a config with a secret → **inspect** state → **grep the plaintext secret** out of the file → **migrate** the backend → **break→fix** with `state rm` → **drift**: mutate the rendered file out-of-band and watch `plan` reconcile → **adopt**: bring a bucket made outside OpenTofu under management with `import {}`, and read it from a second config with a `data` source → **stretch**: the same migration for real, to `backend "s3"` on LocalStack with native locking)* |
| **Environment** | `mock ✓ (no docker)` — Steps 0–7: no cloud, no Docker; `random` + `local` providers only. `localstack ✓` **Step 8 and the Stretch** — the adopt/reference step and the optional S3-backend stretch need Docker/LocalStack on `:4566` and the `hashicorp/aws` provider |
| **Estimated time** | 40 min — 25 for Steps 0–7, ~15 for Step 8 on LocalStack (+ ~15 min optional S3-backend stretch) |

> **OVH track.** The optional S3-backend stretch has an OVH version at
> [`variant/ovh/snippets/s3-backend/`](../../variant/ovh/snippets/s3-backend/README.md)
> — see the [OVH variant entry](../../variant/ovh/README.md).

## Objective

See **what state actually is** and why it matters — then see why it's dangerous.
You'll `apply` a small config that includes a **generated DB password**, inspect
the state with `tofu state list` / `show`, and then — the payoff — **`grep` that
password out of `terraform.tfstate` in plaintext**, even though the CLI redacts
it. That exposure is exactly what **S05 (state encryption)** closes.

Along the way you'll **migrate** the state to a new local path with
`tofu init -migrate-state` (the same mechanic you'd use to move to S3, no cloud
required — and the optional **Stretch** then *does* move it to S3, on LocalStack,
locking included), and run a **break→fix**: `tofu state rm` *forgets* a resource so the
next `plan` wants to recreate it — then `apply` reconciles. Finally you'll
**experience drift**: change the rendered manifest behind OpenTofu's back —
edit it, then delete it — and read the reconciling `plan` that steers reality
back to your config. Last, on LocalStack, you'll **adopt** a bucket that
someone created outside OpenTofu: a plain `apply` fails on the taken name, an
`import {}` block brings the bucket into state without recreating it, and a
`data` source in a second config reads the same bucket without owning it.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/04-state/`:

- `main.tf` — a three-resource config: a `random_password` (the secret), a
  `random_pet`, and the project's `local_file.manifest`, plus two outputs. This is
  the exact HCL S04 teaches; the slide's block is drift-checked to stay
  byte-identical to this file.
- `backend.tf` — the explicit `backend "local"` block, in its own file so the
  backend can be swapped without touching `main.tf`.
- `terraform.tfvars` — the auto-loaded `service` object and `environment`, carried
  forward from stage 5 so the lab runs non-interactively.
- `backend-s3.tf.off` — the Stretch's S3-backend variant, inert until copied to
  `backend-s3.tf`.
- `adopt/` and `reference/` — Step 8's two small AWS-on-LocalStack configs, each
  with its own state (see Step 8).

### Continuity — stage 6 of the `service-manifest` project

This is the stage where the project's own state is the thing under the
microscope. Until now this workdir shared nothing with the rest of Day 1; it
does now.

**Carried forward from stage 5** (`labs/day-1/15-conditions-checks/`): all four
spine addresses — `variable "service"`, `variable "environment"`,
`local_file.manifest` and `output "manifest_path"` — plus the auxiliary
`random_pet.env` and `random_password.session`. The `state list` you are about to
read is a list of *your project's* addresses.

**Deliberately retired here — the stage-5 guards, whose teaching job is done:**
the `precondition`/`postcondition` on `local_file.manifest`, the `precondition`
on `output "manifest_path"`, the `check "secret_strength"` block, and the two
variables that fed them (`max_manifest_bytes`, `min_secret_length`). Assertions
are taught; this stage is about what OpenTofu *remembers*, and a config with no
guards makes the state file easier to read line by line.

**Promoted here, not re-introduced:** `random_password.session` has been in the
config since stage 4, carried forward under the same address — at stage 5 it only
gave the `check` block a threshold to assert on. Here it is the **subject**: its resolved
value lands in `terraform.tfstate` as plaintext, and Step 4 greps it out. Nothing
came back to make that happen; retiring the stage-5 guards simply left it in the
spotlight. (Stage 4's `variable "api_token"` retired at stage 5 and does **not**
return — this stage makes its point with a generated secret instead.)

**Beside the spine, not part of it:** Step 8's `adopt/` and `reference/`
workdirs (an `aws_s3_bucket`, an `import` block, a `data "aws_s3_bucket"`) run
from their own directories with their own state. They add nothing to the
`service-manifest` addresses and retire nothing; the spine's state in this
directory is untouched by them.

**Introduced here, and auxiliary:** the explicit `backend "local"` block — in its
own `backend.tf`, so Step 5 (and the S3 stretch) can migrate it — and
`output "db_password"`, which keeps its own name because it *is* the
plaintext-in-state beat.

## Prerequisites

- `tofu` ≥ 1.9 (`task setup` installs it). Check: `tofu version`.
- `grep` on `PATH`, and `jq` (optional but used in a spoiler) to read the raw
  state JSON. Stock macOS does **not** ship `jq` — install it (`brew install
  jq`) or use the `grep`-only form given in the spoiler.
- Network access the first time (`tofu init` downloads the `random` + `local`
  providers, and in Step 8 `hashicorp/aws`). No Docker, no cloud, no AWS in
  Steps 0–7. **Step 8** needs Docker for LocalStack (`task lab:up`); the
  `import {}` block is in every OpenTofu release (OpenTofu began at 1.6.0;
  Terraform added the block in 1.5), so the ≥ 1.9 floor covers it. **The
  optional Stretch** needs Docker (for LocalStack) and `tofu` **≥ 1.10** (`use_lockfile` is
  an OpenTofu 1.10 feature; the workshop pin 1.10.3 satisfies it — check
  `tofu version` before starting the stretch, and skip it below 1.10).
- Run everything **from the repo clone**.

## Files used

All tracked in `labs/day-1/04-state/` — you run them, you do not paste them:

- `main.tf` — the config: a `random_password`, a `random_pet`, the project's
  `local_file.manifest`, and two outputs.
- `backend.tf` — the explicit `backend "local"` block, split into its own file
  so you can migrate it (Step 5 edits its path; the Stretch swaps the file).
- `backend-s3.tf.off` — the Stretch's `backend "s3"` block for LocalStack,
  inert until you `cp` it to `backend-s3.tf`.
- `terraform.tfvars` — the auto-loaded `service` object and `environment`.
- `adopt/providers.tf`, `adopt/main.tf`, `adopt/import.tf.off` — Step 8's
  adoption config: the AWS provider pointed at LocalStack, the
  `aws_s3_bucket.legacy` resource block, and the inert `import {}` block.
- `reference/providers.tf`, `reference/main.tf` — Step 8's second config: the
  same provider and a read-only `data "aws_s3_bucket"` lookup.
- `.gitignore` — keeps the state (which holds the **plaintext secret** — never
  commit it), `.terraform`, the rendered `out/` file, the migrated `state/`
  dir, and the stretch's swap residue out of version control.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/04-state
ls
```

**Task:** Confirm the config is already present — you author nothing (you only
*edit* the backend path later and copy one `.off` file in Step 8; cleanup reverts
both).

<details><summary>Solution / expected output</summary>

```console
$ ls
adopt  backend-s3.tf.off  backend.tf  main.tf  reference  terraform.tfvars
```

`main.tf`, `backend.tf` and `terraform.tfvars` are tracked in the repo — plus
`backend-s3.tf.off`, the Stretch's inert S3 variant (OpenTofu only loads
config from `*.tf`, `*.tf.json` and `*.tofu` files, and `.off` matches none of
them, so the file is invisible to every step until you activate it). The
`adopt/` and `reference/` directories are Step 8's separate configs; OpenTofu
does not read subdirectories, so they do not affect Steps 1–7. Everything
below runs against these exact files. (`.gitignore` is present too; `ls` hides
dotfiles by default.)
</details>

---

## Step 1 — Read the config: a secret, on purpose

`cat main.tf` and read it top to bottom. The point of interest is
`random_password.session`: a generated secret marked `sensitive` in its output.

<!-- source: labs/day-1/04-state/main.tf -->
```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }
}

# NOTE: where this project's state lives is declared in backend.tf (sibling
# file) — kept separate so the backend can be swapped without touching the
# config the S04 slides teach.

# SPINE — carried forward from stage 5. The state you are about to read is your
# own project's state, not a fresh demo's.
variable "service" {
  description = "The service this config renders a manifest for."
  type = object({
    name     = string
    tier     = string
    replicas = number
  })
}

# SPINE — carried forward from stage 5.
variable "environment" {
  description = "Deployment environment recorded in the rendered manifest."
  type        = string
  default     = "dev"
}

# AUXILIARY — random_password.session, carried forward from stage 5 under the
# same address. It is `sensitive`, so tofu redacts it in CLI output — but the
# RESOLVED value is still written to terraform.tfstate as plaintext JSON. That
# gap is exactly what stage 7 (S05, state encryption) closes.
resource "random_password" "session" {
  length  = 20
  special = true
}

# AUXILIARY — random_pet.env, carried forward from stage 5. It also gives
# `state list` more than one entry to show, `mv`, and `rm`.
resource "random_pet" "env" {
  length = 2
}

# SPINE — local_file.manifest, carried forward from stage 5. It records the
# service name, never the secret — and state stores this file's content too.
resource "local_file" "manifest" {
  filename = "${path.module}/out/${var.service.name}.env"
  content  = <<-EOT
    SERVICE_NAME=${var.service.name}
    SERVICE_TIER=${var.service.tier}
    REPLICAS=${var.service.replicas}
    ENVIRONMENT=${var.environment}
    RELEASE=${random_pet.env.id}
  EOT
}

# SPINE — output manifest_path, carried forward from stage 5.
output "manifest_path" {
  description = "Where the rendered manifest landed (safe to print)."
  value       = local_file.manifest.filename
}

# AUXILIARY — this output IS the plaintext-in-state beat, so it keeps its own
# name: the lab's `grep`/`jq` spoilers and the S04 slide all cite db_password.
output "db_password" {
  description = "The generated secret — sensitive, so redacted in CLI output."
  value       = random_password.session.result
  sensitive   = true
}
```

The backend — *where* this state lives — is deliberately split into its own
file, `backend.tf`, so the rest of the lab can migrate it without touching the
config above:

<!-- source: labs/day-1/04-state/backend.tf -->
```hcl
# Where this project's state lives — kept in its OWN file so the backend can be
# swapped without touching main.tf (the config the S04 slides teach).
#
# Step 5 edits the path below (a learner edit — cleanup reverts it). The
# Stretch parks this whole file as backend.tf.off and activates the S3 variant
# from backend-s3.tf.off instead — same migration, real remote backend.
terraform {
  # State lives on the LOCAL backend by default. This explicit block names the
  # path so we can migrate it later with `tofu init -migrate-state`.
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

**Task:** The `db_password` output is `sensitive = true`. Does that keep the
password *out of the state file*, or only out of the CLI output?

<details><summary>Solution</summary>

**Only out of the CLI output.** `sensitive = true` tells OpenTofu to *redact the
value in terminal output* — `apply` prints `db_password = <sensitive>`, and
`state show` prints `result = (sensitive value)`. It does **nothing** to the file
on disk: `terraform.tfstate` is plaintext JSON, and the resolved password is
stored there as a literal string. You'll prove this in Step 4. `sensitive`
protects your scrollback, not your state file.
</details>

---

## Step 2 — `apply`: generate the secret and write state

```bash
tofu init
tofu apply -auto-approve
```

**Task:** Apply the config. What does the `db_password` output show, and where did
the real value go?

<details><summary>Solution / expected output</summary>

```console
$ tofu init
Initializing the backend...
Successfully configured the backend "local"! OpenTofu will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Installing hashicorp/random v3.9.0...
- Installing hashicorp/local v2.9.0...
...
OpenTofu has been successfully initialized!

$ tofu apply -auto-approve
...
Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + db_password   = (sensitive value)
  + manifest_path = "./out/checkout.env"
random_pet.env: Creating...
random_password.session: Creating...
random_pet.env: Creation complete after 0s [id=crack-parrot]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=00038a4083a27fb3155fc6b00cac682bbcfd30cf]
random_password.session: Creation complete after 0s [id=none]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

db_password = <sensitive>
manifest_path = "./out/checkout.env"
```

The output prints `db_password = <sensitive>` — OpenTofu **redacts** it because
the output is `sensitive`. (`Resources: 3 added` — the `random_password`, the
`random_pet`, and the `local_file`; `db_password` and `manifest_path` are
**outputs**, not resources, so they don't count here.) The real password was written into
`terraform.tfstate`. The generated `service` name (`crack-parrot` here — **yours
will differ**) is safe, so it prints in the clear.
</details>

---

## Step 3 — `state list` and `state show`: the inventory

`tofu state` reads and steers the state file. Start with `list` (the inventory),
then `show` one resource.

```bash
tofu state list
tofu state show random_pet.env
```

**Task:** What does `state list` return, and what is `state show` good for?

<details><summary>Solution / expected output</summary>

```console
$ tofu state list
local_file.manifest
random_password.session
random_pet.env

$ tofu state show random_pet.env
# random_pet.env:
resource "random_pet" "env" {
    id        = "crack-parrot"
    length    = 2
    separator = "-"
}
```

- **`state list`** prints every resource **address** OpenTofu is tracking — your
  inventory. Always start here before any `mv`/`rm`.
- **`state show <addr>`** prints the recorded attributes of **one** resource. It's
  how you check what OpenTofu *thinks* exists without touching the raw JSON. (Your
  `id` will differ.)

</details>

---

## Step 4 — The payoff: the CLI hides the secret, the file does not

Now the security lesson. Ask `state show` for the password, then look at the raw
file.

```bash
tofu state show random_password.session | grep result
grep -o '"result": *"[^"]*"' terraform.tfstate
jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate
```

**Question:** Does `tofu state show random_password.session` reveal the password? Where
*is* the plaintext password, and what does that mean for anyone who can read the
file?

<details><summary>Spoiler — the plaintext secret, verbatim</summary>

`state show` **redacts** it — the CLI honours `sensitive`:

```console
$ tofu state show random_password.session | grep result
    result      = (sensitive value)
```

But the file on disk is plaintext JSON, and `grep`/`jq` pull the password
straight out:

```console
$ grep -o '"result": *"[^"]*"' terraform.tfstate
"result":"U=HUN-S@ajo\u0026a6\u003eQw7:3"

$ jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate
U=HUN-S@ajo&a6>Qw7:3
```

The CLI is **polite** — `state show` prints `(sensitive value)`, which is
reassuring and **misleading**. `terraform.tfstate` is **plaintext JSON**: the
resolved password (`U=HUN-S@ajo&a6>Qw7:3` here — **yours will be a completely
different random string**) sits in the file as a literal, and a one-line `grep`
exposes it. (Two artefacts of the raw read: the state JSON is written **compact**, so there
is no space after `"result":` — hence the `*` in the grep — and OpenTofu's Go
JSON encoder escapes `&`, `<` and `>` as `\u0026`, `\u003c`, `\u003e`. `jq -r`
decodes both away, which is why it is the honest read of what is on disk.)

That file ends up in backups, CI artifacts, a stolen laptop, or an accidental
`git` commit — **anyone who reads the file reads your secret**. This is precisely
the risk **S05 — state encryption** closes: OpenTofu can encrypt state
client-side so what lands on disk is ciphertext, not this.
</details>

---

## Step 5 — Migrate the backend: `tofu init -migrate-state`

You switch where state lives by editing the `backend {}` block and re-initialising.
Here, migrate between two **local paths** — the mechanic is identical for any
backend, and the optional **Stretch** at the end replays exactly this step
against a real (emulated) S3 bucket, locking included. Move the state into a
`state/` subdirectory:

```bash
# edit the backend path in backend.tf (a learner edit — cleanup reverts it)
sed -i.bak 's#path = "terraform.tfstate"#path = "state/terraform.tfstate"#' backend.tf
tofu init -migrate-state
```

**Task:** What does `-migrate-state` prompt for, and what does it do?

<details><summary>Solution / expected output</summary>

`tofu init -migrate-state` detects the backend change and **prompts** before
copying:

```console
$ tofu init -migrate-state
Initializing the backend...

Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "local" backend. No existing state was found in the newly
  configured "local" backend. Do you want to copy this state to the new "local"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes


Successfully configured the backend "local"! OpenTofu will automatically
use this backend unless the backend configuration changes.
...
OpenTofu has been successfully initialized!
```

Answer **`yes`**. OpenTofu **copies** the state to the new path
(`state/terraform.tfstate`) and re-points the working directory. This is exactly
the flow for moving to a remote backend like S3 — you'd change the `backend`
block to `backend "s3" { ... }` and run the same command. (The old
`terraform.tfstate` is left on disk untouched — OpenTofu copies, it doesn't
delete. Cleanup removes it.)

Confirm the migration is a no-op — same state, new location:

```console
$ tofu plan
random_pet.env: Refreshing state... [id=crack-parrot]
...
No changes. Your infrastructure matches the configuration.
```

</details>

---

## Step 6 — Break → fix: `state rm` forgets a resource

`tofu state rm` removes a resource from state **without destroying the real
thing**. That's a sharp edge — do it on purpose and watch what breaks.

```bash
tofu state rm random_pet.env
tofu state list
tofu plan
```

**Task (break):** After `state rm random_pet.env`, what does `state list`
show, and what does the next `plan` want to do — and *why*?

<details><summary>Solution / expected output</summary>

```console
$ tofu state rm random_pet.env
Removed random_pet.env
Successfully removed 1 resource instance(s).

$ tofu state list
local_file.manifest
random_password.session

$ tofu plan
...
Plan: 2 to add, 0 to change, 1 to destroy.
```

`random_pet.env` is **gone from state** — but the config still declares it.
So OpenTofu now believes the pet doesn't exist and plans to **create** it
(`2 to add`: the pet, plus a re-created `checkout.env` whose content references the
new pet id; `1 to destroy`: the stale file). There is no `Changes to Outputs`
section: `manifest_path` reads the manifest's `filename`, a literal in the config,
so it is unaffected. `state rm` **forgets**, it does not
**destroy** — the mismatch between an emptied state and an unchanged config is
what makes the plan want to recreate. In the real world this is how you'd hand a
resource to a different config, or drop an object OpenTofu should no longer manage.
</details>

Now **fix** it — reconcile state back to the config with `apply`:

```bash
tofu apply -auto-approve
tofu state list
```

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
random_pet.env: Creating...
random_pet.env: Creation complete after 0s [id=fleet-kite]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=b4c6c02cb83ba415916d5b90aeac748a47d67227]

Apply complete! Resources: 2 added, 0 changed, 1 destroyed.

Outputs:

db_password = <sensitive>
manifest_path = "./out/checkout.env"

$ tofu state list
local_file.manifest
random_password.session
random_pet.env
```

`apply` reconciles: it re-creates the forgotten `random_pet.env` and rewrites
the file, so `state list` shows all three again. Note the pet name **changed**
(`crack-parrot` → `fleet-kite` here — yours will differ): because state *forgot*
the old pet, OpenTofu generated a **fresh** one rather than reusing the old value.
That's the lesson — state is what preserves generated values across runs; lose the
state entry and you lose the value. (The `db_password` was untouched — it was
never `rm`'d — so it kept its value.)
</details>

---

## Step 7 — Drift: the world changes behind OpenTofu's back

Step 6 broke the **memory** (`state rm`). **Drift** is the opposite failure:
state is fine, but someone changes the **actual** — a "quick fix" applied
straight to the artifact, never through OpenTofu. That is the third corner of
the desired/state/actual triangle from the S04 slides. Cause some drift on
purpose: bump the replica count in the **rendered manifest**, by hand, behind
OpenTofu's back.

```bash
sed -i.drift 's/REPLICAS=2/REPLICAS=6/' out/checkout.env && rm out/checkout.env.drift
cat out/checkout.env
tofu plan
```

**Task (break — the drift *is* the break):** You edited the file, not the
config. Does `tofu plan` even notice? What does it propose — and whose replica
count wins, yours or the config's?

<details><summary>Solution / expected output — the reconciling plan, verbatim</summary>

`plan` notices immediately — the **refresh** reads the real file back before
diffing:

```console
$ tofu plan
random_pet.env: Refreshing state... [id=fleet-kite]
random_password.session: Refreshing state... [id=none]
local_file.manifest: Refreshing state... [id=b4c6c02cb83ba415916d5b90aeac748a47d67227]

OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

OpenTofu will perform the following actions:

  # local_file.manifest will be created
  + resource "local_file" "manifest" {
      + content              = <<-EOT
            SERVICE_NAME=checkout
            SERVICE_TIER=standard
            REPLICAS=2
            ENVIRONMENT=staging
            RELEASE=fleet-kite
        EOT
      + content_base64sha256 = (known after apply)
      + content_base64sha512 = (known after apply)
      + content_md5          = (known after apply)
      + content_sha1         = (known after apply)
      + content_sha256       = (known after apply)
      + content_sha512       = (known after apply)
      + directory_permission = "0777"
      + file_permission      = "0777"
      + filename             = "./out/checkout.env"
      + id                   = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

Read the diff closely — it is the whole lesson:

- The refresh compared **actual** (your edited file) against **state** (the
  recorded content) and caught the mismatch. That comparison *is* drift
  detection — nobody told OpenTofu about your edit.
- The proposed `content` says **`REPLICAS=2`** — the *config's* value, not your
  `6`. The plan reconciles **actual back to desired**; it never negotiates.
  Your hand-edit is scheduled for deletion.
- The action is `+ create` rather than `~ update`: the `local` provider treats
  a changed checksum as "the artifact I made is gone" and drops the resource
  from the refreshed state, so the reconciliation is a rebuild. A provider that
  can patch attributes in place (tags on a cloud VM, say) would show
  `~ update in-place` under a `# … has changed outside of OpenTofu` note —
  same instinct, gentler surgery.

The second drift flavour — **deletion** — is even more direct. Run
`rm out/checkout.env` and `tofu plan` again: it produces this **same** plan.
Refresh finds no file at all, state drops the resource, and the reconciliation
is `1 to add`. For this provider, hand-edited and missing collapse into the
same answer: rebuild from desired.
</details>

Now **fix** it — reconciling drift is just an `apply`:

```bash
tofu apply -auto-approve
cat out/checkout.env
tofu plan
```

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
Plan: 1 to add, 0 to change, 0 to destroy.
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=b4c6c02cb83ba415916d5b90aeac748a47d67227]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

db_password = <sensitive>
manifest_path = "./out/checkout.env"

$ cat out/checkout.env
SERVICE_NAME=checkout
SERVICE_TIER=standard
REPLICAS=2
ENVIRONMENT=staging
RELEASE=fleet-kite

$ tofu plan
...
No changes. Your infrastructure matches the configuration.
```

`REPLICAS=2` is back — the hand-edit is gone, and the follow-up `plan` is a
no-op: desired == state == actual again. Two details worth savouring:

- The re-created file has the **same id** (`b4c6c02c…`) as before the drift:
  for `local_file` the id *is* the content's SHA-1 hash, and the content is
  back to exactly what the config declares.
- Contrast with Step 6: this time `random_pet.env` kept its name
  (`fleet-kite`) and `db_password` kept its value, because **state never forgot
  anything** — only reality drifted. `state rm` costs you generated values;
  repairing drift does not.

This is why state exists: without the recorded content, OpenTofu could not have
told your 2 a.m. hotfix apart from its own work.
</details>

---

## Step 8 — Adopt a bucket that already exists (`localstack ✓`)

Steps 6 and 7 were state and reality falling out of step *after* OpenTofu built
something. The case you will meet first at work is the reverse: a bucket someone
clicked together in the console years ago, which OpenTofu has **never** seen.
You do not recreate it. You **adopt** it with an `import {}` block, and where you
only need to *read* it, you **reference** it with a `data` source instead.

This step runs against **LocalStack** (Docker on `127.0.0.1:4566`), with the
`hashicorp/aws` provider in two small workdirs of their own:

- `adopt/` — `providers.tf` (the LocalStack-pointed AWS provider), `main.tf` (the
  resource block that describes the bucket, plus an output), and
  `import.tf.off` (the import block, inert until you copy it to `import.tf`).
- `reference/` — a **second** config with its own state: a
  `data "aws_s3_bucket"` lookup of the same bucket, plus an output.

Neither touches the `service-manifest` spine: its state stays in
`labs/day-1/04-state/`, and these two directories keep separate state files.

The AWS CLI calls below use the `awslocal` wrapper that ships **inside** the
LocalStack container (`docker exec opentofu-workshop-localstack awslocal …`), the
same call the Stretch uses, so there is nothing extra to install. If you have the
AWS CLI on your host, `aws --endpoint-url=http://localhost:4566 s3 mb …` with the
dummy credentials from `.env.example` does the same thing (see
`setup/localstack.md`).

> Console output below is from a real run on `tofu v1.10.3` and
> `hashicorp/aws v5.100.0` against `localstack/localstack:4.9.2`. Timestamps and
> the `grant` id will differ on your machine.

### 8a — Someone clicks a bucket into existence

Start LocalStack, then play the colleague with console access: create the
bucket **outside** OpenTofu.

```bash
task lab:up                      # LocalStack on :4566 (waits until healthy)
docker exec opentofu-workshop-localstack awslocal s3 mb s3://workshop-legacy-reports
docker exec opentofu-workshop-localstack awslocal s3 ls
cd "$(git rev-parse --show-toplevel)"/labs/day-1/04-state/adopt
tofu init
```

**Task:** The bucket exists. Does OpenTofu know about it?

<details><summary>Solution / expected output</summary>

```console
$ docker exec opentofu-workshop-localstack awslocal s3 mb s3://workshop-legacy-reports
make_bucket: workshop-legacy-reports

$ docker exec opentofu-workshop-localstack awslocal s3 ls
2026-09-25 10:24:09 workshop-legacy-reports

$ tofu init
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 5.0.0, < 6.0.0"...
- Installing hashicorp/aws v5.100.0...
...
OpenTofu has been successfully initialized!
```

No. The bucket is real, but this workdir has **no state at all**: `init`
installs the provider, and only an apply (or an import) writes state. Reality
has something that OpenTofu has no record of. (Your `hashicorp/aws` patch
version may differ inside `>= 5.0, < 6.0`.)
</details>

### 8b — Break: write the resource block and just apply

`adopt/main.tf` holds the resource block you would write first: it describes
the existing bucket by name.

<!-- source: labs/day-1/04-state/adopt/main.tf -->
```hcl
# The resource block you write FIRST: it describes the bucket someone created
# in the console. On its own it means "create this" — the import block
# (import.tf, activated in Step 8c) turns it into "adopt this".
resource "aws_s3_bucket" "legacy" {
  bucket = "workshop-legacy-reports"
}

output "legacy_bucket_arn" {
  description = "ARN of the adopted bucket, read from state after the import."
  value       = aws_s3_bucket.legacy.arn
}
```

Apply it as it stands:

```bash
tofu apply -auto-approve
```

**Task (break):** What does the plan propose, and why does the apply fail?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
  # aws_s3_bucket.legacy will be created
  + resource "aws_s3_bucket" "legacy" {
      + bucket                      = "workshop-legacy-reports"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + legacy_bucket_arn = (known after apply)
aws_s3_bucket.legacy: Creating...
╷
│ Error: creating S3 Bucket (workshop-legacy-reports): BucketAlreadyExists
│
│   with aws_s3_bucket.legacy,
│   on main.tf line 4, in resource "aws_s3_bucket" "legacy":
│    4: resource "aws_s3_bucket" "legacy" {
│
╵
```

State has no entry for `aws_s3_bucket.legacy`, so a resource block on its own
means **create**: `1 to add`. The create call then hits the real bucket's name
and fails. Nothing changed: the failed apply leaves an empty state and the
bucket as it was. A resource block describes the object; it does not say that
the object already exists. That is the import block's job.
</details>

### 8c — Fix: add the `import {}` block, plan, apply, remove it

Activate the tracked import block (the same `.off` pattern as the Stretch's
backend) and read it:

<!-- source: labs/day-1/04-state/adopt/import.tf.off -->
```hcl
# import block: in every OpenTofu release (Terraform 1.5+).
import {
  # to: the config address that will own it
  to = aws_s3_bucket.legacy
  # id: the real object's id (for S3, its name)
  id = "workshop-legacy-reports"
}
# Plan: "will be imported". Apply. Then delete me.
```

```bash
cp import.tf.off import.tf
tofu plan
```

**Task:** Find the plan summary. How many resources will be **added**? And what
does "will be imported" mean for state?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
aws_s3_bucket.legacy: Preparing import... [id=workshop-legacy-reports]
aws_s3_bucket.legacy: Refreshing state... [id=workshop-legacy-reports]

OpenTofu will perform the following actions:

  # aws_s3_bucket.legacy will be imported
    resource "aws_s3_bucket" "legacy" {
        arn                         = "arn:aws:s3:::workshop-legacy-reports"
        bucket                      = "workshop-legacy-reports"
        bucket_domain_name          = "workshop-legacy-reports.s3.amazonaws.com"
        bucket_regional_domain_name = "workshop-legacy-reports.s3.us-east-1.amazonaws.com"
        hosted_zone_id              = "Z3AQBSTGFYJSTF"
        id                          = "workshop-legacy-reports"
        object_lock_enabled         = false
        region                      = "us-east-1"
        request_payer               = "BucketOwner"
        tags                        = {}
        tags_all                    = {}
        ...
    }

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + legacy_bucket_arn = "arn:aws:s3:::workshop-legacy-reports"
```

**`1 to import, 0 to add`**: no bucket gets created. "Will be imported" means
the apply will **write a state entry** that maps the address
`aws_s3_bucket.legacy` to the real bucket `workshop-legacy-reports`. Nothing on
the bucket itself changes. Every attribute shown (`arn`, `region`, the
`grant`, `versioning`, …) was **read from the live bucket** during
`Preparing import...`; you never wrote them. **`0 to change`** matters as much
as the import: it says your resource block already matches the real bucket, so
adopting it will not modify it.
</details>

Apply the adoption, check the inventory, then retire the import block:

```bash
tofu apply -auto-approve
tofu state list
rm import.tf
tofu plan
```

**Task:** What does the apply summary call what happened? What does
`state list` show now, and what does the plan say once the import block is gone?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
...
aws_s3_bucket.legacy: Importing... [id=workshop-legacy-reports]
aws_s3_bucket.legacy: Import complete [id=workshop-legacy-reports]

Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.

Outputs:

legacy_bucket_arn = "arn:aws:s3:::workshop-legacy-reports"

$ tofu state list
aws_s3_bucket.legacy

$ rm import.tf
$ tofu plan
aws_s3_bucket.legacy: Refreshing state... [id=workshop-legacy-reports]

No changes. Your infrastructure matches the configuration.
```

**`1 imported, 0 added`**: the bucket was adopted, not recreated. `state list`
now shows `aws_s3_bucket.legacy`, the same inventory view as Step 3, and the
address maps to the bucket that already existed. From here the bucket is
**managed**: a config change produces a plan against it, and `tofu destroy` in
this directory would delete it. With the import block gone the plan is still
`No changes`, because state now holds the mapping the block was there to
create. Delete import blocks once the adoption has been applied; they have no
further job.
</details>

### 8d — Reference it, don't own it: a `data` source

Import is a change of **ownership**. When the bucket belongs to someone else
(another team, another stack, or the console crowd who still run it) and you
only need its attributes, use a **data source** instead. The `reference/`
workdir is that second config:

<!-- source: labs/day-1/04-state/reference/main.tf -->
```hcl
# Reference it, don't own it: a data source READS the bucket at plan time.
# It never enters this config's managed state, so destroy cannot touch it.
data "aws_s3_bucket" "legacy" {
  bucket = "workshop-legacy-reports"
}

output "legacy_bucket_arn" {
  description = "ARN of the bucket another config owns, looked up read-only."
  value       = data.aws_s3_bucket.legacy.arn
}
```

```bash
cd "$(git rev-parse --show-toplevel)"/labs/day-1/04-state/reference
tofu init
tofu apply -auto-approve
tofu state list
tofu destroy -auto-approve
docker exec opentofu-workshop-localstack awslocal s3 ls
```

**Task:** How many resources does the apply add? What does `state list` show,
and does `destroy` in this directory delete the bucket?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
data.aws_s3_bucket.legacy: Reading...
data.aws_s3_bucket.legacy: Read complete after 0s [id=workshop-legacy-reports]

Changes to Outputs:
  + legacy_bucket_arn = "arn:aws:s3:::workshop-legacy-reports"
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

legacy_bucket_arn = "arn:aws:s3:::workshop-legacy-reports"

$ tofu state list
data.aws_s3_bucket.legacy

$ tofu destroy -auto-approve
data.aws_s3_bucket.legacy: Reading...
data.aws_s3_bucket.legacy: Read complete after 0s [id=workshop-legacy-reports]

Changes to Outputs:
  - legacy_bucket_arn = "arn:aws:s3:::workshop-legacy-reports" -> null
...
Destroy complete! Resources: 0 destroyed.

$ docker exec opentofu-workshop-localstack awslocal s3 ls
2026-09-25 10:24:09 workshop-legacy-reports
```

**`0 added`**, and **`0 destroyed`**. The data source is read on every plan and
its attributes (here the ARN) feed your config, but it is never created,
changed or destroyed from this directory. `state list` does print
`data.aws_s3_bucket.legacy`: OpenTofu caches the last read in state under a
`data.` address, and that cache is not ownership. The bucket survives the
destroy because this config never owned it. The `adopt/` config does own it,
which is why the Cleanup below destroys it from there.

Rule of thumb: if you are taking over the bucket's lifecycle, **import** it. If
someone else keeps running it, **reference** it.
</details>

## Expected observations

- **State is the map** from config addresses (`random_pet.env`) to real
  resource IDs — the memory that makes a `plan` a diff.
- `tofu state list` is the inventory; `state show` dumps one resource; `state mv`
  renames in state; `state rm` **forgets** (next `plan` wants to recreate).
- A `sensitive` output is **redacted by the CLI** (`state show` →
  `(sensitive value)`) but stored **in plaintext** in `terraform.tfstate` — a
  `grep` finds it. **Never commit the state file.**
- `tofu init -migrate-state` **copies** state to a new backend location (here a
  local path; the same flow moves you to S3) after a `yes` prompt.
- `state rm` then `apply` demonstrates that state — not config — is what preserves
  generated values across runs.
- **Drift** is an out-of-band change to the real world (`out/checkout.env`
  edited or deleted by hand). The **refresh** phase of `tofu plan` catches it,
  and the plan reconciles **actual back to desired** — the config's values win,
  and the fix is a plain `apply`.
- **Adoption** is the other direction: an object that exists but is not in
  state. A resource block alone plans `1 to add` and the apply fails
  (`BucketAlreadyExists`). With an `import {}` block the plan reads
  `1 to import, 0 to add, 0 to change`, the apply reports `1 imported`,
  `state list` shows `aws_s3_bucket.legacy`, and after the block is deleted the
  plan is `No changes`.
- A **`data` source** references an object without owning it: `0 added`,
  `0 destroyed`, the bucket survives `destroy`, and `state list` shows only the
  cached `data.aws_s3_bucket.legacy` read.
- *(Stretch)* A **remote backend** is the same migration pointed at shared
  storage: `backend "s3"` + `tofu init -migrate-state` moves this exact state
  into a LocalStack bucket, and `use_lockfile = true` (OpenTofu ≥ 1.10) makes
  a second actor's operation **wait or fail loudly** instead of racing — the
  lock is a real, inspectable `.tflock` object next to the state.

## Cleanup / panic reset

Destroy Step 8's adopted bucket (on LocalStack) and the local resources, restore
the tracked `backend.tf`, and remove all generated residue — including the state
file that holds the plaintext secret. Nothing touches real AWS, so nothing to
bill or leak. This block is safe from
**any** point in the lab, including mid-stretch (the stretch lines are no-ops if
you never started it):

```bash
cd labs/day-1/04-state
tofu -chdir=adopt destroy -auto-approve || true       # Step 8: deletes the adopted bucket (needs LocalStack up)
rm -f adopt/import.tf                                 # Step 8: the activated import block (the tracked .off stays)
rm -rf adopt/.terraform adopt/.terraform.lock.hcl reference/.terraform reference/.terraform.lock.hcl
find adopt reference -maxdepth 1 -name 'terraform.tfstate*' -delete   # Step 8 state files
tofu destroy -auto-approve || true                    # best-effort — see the note below
rm -f backend-s3.tf                                   # stretch: retire the activated S3 variant (the tracked .off stays)
mv -f backend.tf.off backend.tf 2>/dev/null || true   # stretch: un-park the local backend
mv -f backend.tf.bak backend.tf 2>/dev/null || true   # revert the Step 5 backend edit
rm -rf .terraform .terraform.lock.hcl state out backend.tf.bak
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # all root state incl. secret-bearing *.<ts>.backup (shell-agnostic)
task lab:down 2>/dev/null || true                     # Step 8 / stretch: stop LocalStack, wipe its volume
git status --short .      # expect: no output
```

<details><summary>Expected output</summary>

```console
$ tofu -chdir=adopt destroy -auto-approve
aws_s3_bucket.legacy: Refreshing state... [id=workshop-legacy-reports]
...
Plan: 0 to add, 0 to change, 1 to destroy.
...
aws_s3_bucket.legacy: Destroying... [id=workshop-legacy-reports]
aws_s3_bucket.legacy: Destruction complete after 0s

Destroy complete! Resources: 1 destroyed.

$ tofu destroy -auto-approve
random_password.session: Destroying... [id=none]
random_password.session: Destruction complete after 0s
local_file.manifest: Destroying... [id=b4c6c02cb83ba415916d5b90aeac748a47d67227]
local_file.manifest: Destruction complete after 0s
random_pet.env: Destroying... [id=fleet-kite]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

The generated state (with its plaintext secret), `.terraform`, the rendered
`out/` file, the migrated `state/` dir, and the `backend.tf.bak` from Step 5 are
all gitignored or removed; the panic reset leaves the tracked `main.tf`,
`backend.tf`, `backend-s3.tf.off`, `terraform.tfvars` and the `adopt/` /
`reference/` files exactly as CI verified them (backend path back to
`terraform.tfstate`). Order matters: `tofu destroy`
runs **before** the file restores, so whatever backend is active *right now* —
the migrated `state/` path, or the stretch's S3 bucket — is the one the destroy
reads, and it actually removes the resources.

**Step 8's bucket goes first, and from `adopt/`:** that config owns the
bucket after the import, so its destroy deletes it — `1 destroyed`. The
`reference/` config never owned it and has nothing to destroy. If you stopped
before the importing apply in 8c (bucket created, never imported), the `adopt/`
destroy finds nothing in state and reports `0 destroyed`; the bucket then goes with LocalStack's
volume at `task lab:down` (the workshop runs LocalStack with `PERSISTENCE=0`).
To remove it by hand without stopping LocalStack:
`docker exec opentofu-workshop-localstack awslocal s3 rb s3://workshop-legacy-reports`.

**Why `|| true` on the destroy is honest, not sloppy:** every resource in
Steps 0–7 is local to this directory — two random values and one rendered file under
`out/`. If the destroy cannot reach its state (say you panic mid-stretch after
`task lab:down` wiped the bucket), nothing real survives it anyway: `rm -rf …
out` removes the only artifact, and the random values die with the state. The
`find` sweep catches every `terraform.tfstate*` in the root — including the
timestamped `.backup` that `tofu state rm` leaves — so no plaintext-secret file
survives either. The stretch lines are ordered restore-S3-variant-out-first so
the directory never ends up with **two** active backend files.
</details>

## Stretch (optional)

### The real thing — this state, in S3, with locking (`localstack ✓`, ~15 min)

The project's state has so far lived on **local paths**. This stretch replays Step 5's exact
mechanic against a real (emulated) **S3 remote backend** — the setup a team
shares — and then proves the thing local state can never give you: a **lock**.
Continue straight from the end of Step 7 (state migrated to
`state/terraform.tfstate`, all three resources applied), in
`labs/day-1/04-state`. If you did Step 8, `cd ..` out of `reference/` first:
Step 8 never touched this directory's state, and LocalStack can stay up.

**Requirements:** Docker (for LocalStack on `:4566`) and `tofu` **≥ 1.10** —
`use_lockfile` is OpenTofu 1.10's native S3 locking (no DynamoDB table, no extra
infrastructure: the lock is an S3 object). The workshop pin (1.10.3) qualifies;
if `tofu version` says less, upgrade first (`task setup`) — without 1.10 the
backend block below fails on an unsupported argument, and dropping the
`use_lockfile` line would migrate fine but skip the whole locking lesson.

> Console output in the spoilers is from a real run of this stretch on
> `tofu v1.12.5` against `localstack/localstack:4.9.2`. Generated names, ids,
> lock IDs, request IDs, and `user@host` values will differ on your machine —
> and your pet name will match *your* Step-2 value, not this run's. The
> `Lock Info` block's `Version:` line stamps the tofu that *took* the lock, so
> it reads `1.12.5` here; on the workshop pin you will see `1.10.3` (or
> whatever your `tofu version` says).

#### S-1 — Swap the backend, break first

Bring up LocalStack, park the local backend with the house `.off` pattern,
activate the tracked S3 variant — and run the migration **before creating the
bucket**, because that failure is worth reading:

```bash
task lab:up                        # LocalStack on :4566 (waits until healthy)
mv backend.tf backend.tf.off       # park the local backend (cleanup restores it)
cp backend-s3.tf.off backend-s3.tf # activate the S3 variant — cat it, read every line
tofu init -migrate-state
```

**Task (break):** The bucket `tofu-state` does not exist yet. What exactly does
`init -migrate-state` do to your state before it fails — and how do you know?

<details><summary>Spoiler — the real error, and why it is a safe one</summary>

```console
$ tofu init -migrate-state
Initializing the backend...
OpenTofu detected that the backend type changed from "local" to "s3".
╷
│ Error: Error inspecting states in the "local" backend:
│     S3 bucket does not exist.
│
│ The referenced S3 bucket must have been previously created. If the S3 bucket
│ was created within the last minute, please wait for a minute or two and try
│ again.
│
│ Error: operation error S3: ListObjectsV2, https response error StatusCode: 404, RequestID: 5de28327-b3f4-4fab-bb8f-98378b897fe5, HostID: s9lzHYrFp76ZVxRcpX9+5cjAnEH2ROuNkd2BHfIa6UkFVdtjf5mKR3/eTPFvsiP/XV/VLi31234=, NoSuchBucket: The specified bucket does not exist
│
│ Prior to changing backends, OpenTofu inspects the source and destination
│ states to determine what kind of migration steps need to be taken, if any.
│ OpenTofu failed to load the states. The data in both the source and the
│ destination remain unmodified. Please resolve the above error and try again.
╵
```

**Nothing**, and the error says so: "The data in both the source and the
destination remain unmodified." Backend migration inspects both ends **before**
touching either, so a botched target (missing bucket, wrong endpoint, LocalStack
not running) fails *closed* — your state is still exactly where it was, and the
panic reset works from this point like from any other. The backend never
auto-creates its bucket: state storage is deliberately provisioned outside the
config whose state it holds (otherwise the config would need state to create the
place its state lives — a bootstrap cycle).
</details>

#### S-2 — Fix: create the bucket, migrate for real

The fix is one bucket. `awslocal` (LocalStack's AWS CLI wrapper) ships inside
the container, so this works with nothing extra installed:

```bash
docker exec opentofu-workshop-localstack awslocal s3 mb s3://tofu-state
tofu init -migrate-state
```

(If you have `awslocal` on your `PATH`, plain `awslocal s3 mb s3://tofu-state`
is the same call.)

**Task:** Answer the copy prompt, then **prove** the state now lives in the
bucket — with the AWS CLI, not with tofu.

<details><summary>Spoiler — migration prompt, and the state object in the bucket</summary>

```console
$ docker exec opentofu-workshop-localstack awslocal s3 mb s3://tofu-state
make_bucket: tofu-state

$ tofu init -migrate-state
Initializing the backend...
OpenTofu detected that the backend type changed from "local" to "s3".

Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "s3"! OpenTofu will automatically
use this backend unless the backend configuration changes.
...
OpenTofu has been successfully initialized!
```

Answer **`yes`** — the same prompt as Step 5, because it *is* Step 5: only the
destination differs. Now read the bucket directly:

```console
$ docker exec opentofu-workshop-localstack awslocal s3 ls --recursive s3://tofu-state
2026-08-30 12:40:28       2276 day-1/04-state/terraform.tfstate

$ tofu plan
random_pet.env: Refreshing state... [id=great-sunbird]
random_password.session: Refreshing state... [id=none]
local_file.manifest: Refreshing state... [id=1ff1617c32b0991c3a15a0d1444d0179a245f74f]

No changes. Your infrastructure matches the configuration.
```

The state file is an **object in the bucket** at the `key` from
`backend-s3.tf`, and the follow-up `plan` is a no-op — same state, new home.
Sobering Step-4 postscript: that object is the same plaintext JSON, secret
included. A real team bucket needs encryption and access control (S05's
client-side encryption composes with exactly this backend). And note what your
working directory no longer has: no root `terraform.tfstate` for this backend —
the directory now only *points* at state, which is the collaboration model:
**many working copies, one state**.
</details>

#### S-3 — Two actors, one state: make the lock real

This is why teams use remote state. Your "second actor" is just a second
terminal in the same directory — exactly what a colleague's checkout of this
repo would be: a different working copy pointing at the **same** bucket and key.
First, actor A causes drift and starts an apply **without** auto-approve, so the
apply sits at its confirmation prompt — *holding the lock*:

```bash
# Terminal A — drift, then an apply that waits for a human
rm out/checkout.env
tofu apply          # leave it sitting at "Enter a value:" — do NOT answer yet
```

While A waits, actor B (second terminal, same directory) inspects and then
tries to plan:

```bash
# Terminal B — the lock is a real object; then contention, for real
docker exec opentofu-workshop-localstack awslocal s3 ls --recursive s3://tofu-state
tofu plan
```

**Task:** What extra object exists while A's apply is pending? What happens to
B's `plan`, and what does the error tell you about **who** holds the lock? Then
let A answer `yes` and re-run B's two commands.

<details><summary>Spoiler — the `.tflock` object and the contention error, verbatim</summary>

While A sits at the prompt, the lock is *visible* — `use_lockfile = true` means
a sibling `.tflock` object next to the state:

```console
$ docker exec opentofu-workshop-localstack awslocal s3 ls --recursive s3://tofu-state
2026-08-30 12:40:28       2276 day-1/04-state/terraform.tfstate
2026-08-30 12:41:08        227 day-1/04-state/terraform.tfstate.tflock
```

And B's `plan` — which must also take the lock — fails **loudly, with a dossier**
(user and host sanitised here; yours shows who really holds it):

```console
$ tofu plan
╷
│ Error: Error acquiring the state lock
│
│ Error message: operation error S3: PutObject, https response error
│ StatusCode: 412, RequestID: 4fcf8c0c-ed1e-4249-b221-ae785ecdb70a, HostID:
│ s9lzHYrFp76ZVxRcpX9+5cjAnEH2ROuNkd2BHfIa6UkFVdtjf5mKR3/eTPFvsiP/XV/VLi31234=,
│ api error PreconditionFailed: At least one of the pre-conditions you
│ specified did not hold
│ Lock Info:
│   ID:        5bbb5700-240a-64be-b0de-39effcb9e17c
│   Path:      tofu-state/day-1/04-state/terraform.tfstate
│   Operation: OperationTypeApply
│   Who:       alex@laptop
│   Version:   1.12.5
│   Created:   2026-08-30 12:41:08.197135 +0000 UTC
│   Info:
│
│ OpenTofu acquires a state lock to protect the state from being written
│ by multiple users at the same time. Please resolve the issue above and try
│ again. For most commands, you can disable locking with the "-lock=false"
│ flag, but this is not recommended.
╵
```

Read the mechanism out of the error: the lock is taken by writing the
`.tflock` object with an HTTP **precondition** ("only if it does not already
exist" — hence the `412 PreconditionFailed`), which S3 evaluates atomically.
That conditional write *is* the mutex — no lock server, no DynamoDB table. The
`Lock Info` block is the collaboration story in miniature: **who** (`Who:` is
the holder's `user@host`), **what** (`Operation: OperationTypeApply`), **since
when** — everything you need to walk over and ask "are you done?" instead of
corrupting shared state. (`force-unlock` exists for a *crashed* holder; against
a live one it is how you get the corruption locking prevents.)

Now let A answer `yes`. The apply repairs the drift, and on completion releases
the lock — B's world immediately works again:

```console
$ docker exec opentofu-workshop-localstack awslocal s3 ls --recursive s3://tofu-state
2026-08-30 12:40:28       2276 day-1/04-state/terraform.tfstate

$ tofu plan
No changes. Your infrastructure matches the configuration.
```

The `.tflock` object is gone — held for the duration of the operation, not a
second longer. Contrast with Step 7's drift beat: same repair, but this time a
second actor was **structurally prevented** from racing it.
</details>

#### S-4 — Migrate back home

Undo the swap — the reverse migration, with one new wrinkle worth reading:

```bash
rm backend-s3.tf                 # deactivate the S3 variant (the tracked .off copy stays)
mv backend.tf.off backend.tf     # un-park the local backend
tofu init -migrate-state
tofu state list
```

<details><summary>Spoiler — the overwrite prompt (this one is different, on purpose)</summary>

```console
$ tofu init -migrate-state
Initializing the backend...
OpenTofu detected that the backend type changed from "s3" to "local".

Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "s3" backend to the
  newly configured "local" backend. An existing non-empty state already exists in
  the new backend. The two states have been saved to temporary files that will be
  removed after responding to this query.

  Previous (type "s3"): /tmp/.../1-s3.tfstate
  New      (type "local"): /tmp/.../2-local.tfstate

  Do you want to overwrite the state in the new backend with the previous state?
  Enter "yes" to copy and "no" to start with the existing state in the newly
  configured "local" backend.

  Enter a value: yes

Successfully configured the backend "local"! OpenTofu will automatically
use this backend unless the backend configuration changes.

$ tofu state list
local_file.manifest
random_password.session
random_pet.env
```

This prompt is **not** the one from S-2 — read why: migration **copies**, it
never deletes the source, so `state/terraform.tfstate` still holds the stale
pre-S3 snapshot. OpenTofu finds state at **both** ends, saves both to temp files
(paths shortened here) for you to diff if in doubt, and asks to **overwrite**.
`yes` makes the S3 copy — the current one, with S-3's apply in it — win. The
same copy-semantics also means the bucket still holds its state object right
now, plaintext secret and all, which is exactly why the panic reset's
`task lab:down` removes the LocalStack **volumes**, not just the container.

From here you are back on the Step-7 footing — finish with the normal
**Cleanup / panic reset** above (its stretch lines retire `backend.tf.off` /
LocalStack even if you bail out mid-stretch instead).
</details>

### Smaller stretches

- Rename the resource cleanly with `state mv`. Pick the **auxiliary** pet, never a
  spine address: rename it **everywhere in `main.tf`** — the block label
  `random_pet "env"` **and** its reference `random_pet.env.id` in
  `local_file.manifest`'s `content` — to `stage`. Then run
  `tofu state mv random_pet.env random_pet.stage` **before** planning. The `plan`
  is then a no-op — you renamed the *address* in both config and state, so
  OpenTofu keeps the same real object instead of destroy-recreating it. (Skip the
  `state mv` and `plan` shows `2 to add, 2 to destroy` — the rename becomes a
  replacement, and it cascades into the manifest that references the pet.)

  <details><summary>Solution / expected output (the state-only rename)</summary>

  ```console
  $ tofu state mv random_pet.env random_pet.stage
  Move "random_pet.env" to "random_pet.stage"
  Successfully moved 1 object(s).
  ```

  With the config fully renamed to `random_pet "stage"` — the block **and** its
  reference — the address in state and the address in config match again, so
  `tofu plan` reports `No changes`. `state mv` is the tool for refactoring a
  resource's *address* without touching the real resource. Restore `"env"`
  everywhere afterwards, or run the panic reset. (Note what you did **not**
  rename: `local_file.manifest` and `output "manifest_path"` are spine addresses,
  carried unchanged through every Day-1 stage.)
  </details>
- Inspect the whole state as JSON with `tofu show -json | jq` and find every
  `sensitive_values` block — OpenTofu *marks* which attributes are sensitive, but
  still stores their plaintext right beside the marker. That contrast is the whole
  argument for S05.
- **Let OpenTofu draft the resource block** (Step 8, needs LocalStack up and the
  bucket from 8a). With an `import {}` block and **no** resource block,
  `tofu plan -generate-config-out=generated.tf` writes a resource block from
  what the provider reads back. Run it in a throwaway directory so the `adopt/`
  state is untouched (from `labs/day-1/04-state/adopt`):

  ```bash
  mkdir -p /tmp/adopt-draft
  cp providers.tf /tmp/adopt-draft/
  cp import.tf.off /tmp/adopt-draft/import.tf
  cd /tmp/adopt-draft
  tofu init
  tofu plan -generate-config-out=generated.tf
  cat generated.tf
  ```

  <details><summary>Solution / expected output (the draft needs one fix)</summary>

  ```console
  $ tofu plan -generate-config-out=generated.tf
  aws_s3_bucket.legacy: Preparing import... [id=workshop-legacy-reports]
  aws_s3_bucket.legacy: Refreshing state... [id=workshop-legacy-reports]

  Planning failed. OpenTofu encountered an error while generating this plan.

  ╷
  │ Warning: Config generation is experimental
  ...
  │ Error: Conflicting configuration arguments
  │
  │   with aws_s3_bucket.legacy,
  │   on generated.tf line 1:
  │   (source code not available)
  │
  │ "bucket": conflicts with bucket_prefix
  ╵

  $ cat generated.tf
  # __generated__ by OpenTofu
  # Please review these resources and move them into your main configuration files.

  # __generated__ by OpenTofu
  resource "aws_s3_bucket" "legacy" {
    bucket              = "workshop-legacy-reports"
    bucket_prefix       = ""
    force_destroy       = null
    object_lock_enabled = false
    tags                = {}
    tags_all            = {}
  }
  ```

  The file is written even though the plan fails, and it is a **draft**: the
  provider reports both `bucket` and an empty `bucket_prefix`, which the schema
  forbids together. Delete the `bucket_prefix` line and `tofu plan` reads
  `Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.` The generator saves
  typing on a resource with many attributes; you still review every line before
  it goes into your config. Clean up with `cd - && rm -rf /tmp/adopt-draft`
  (it has its own state; the bucket stays owned by `adopt/`).
  </details>
