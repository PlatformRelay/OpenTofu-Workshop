# Lab 04 — read and steer state (list / show / mv / rm, drift + a plaintext secret)

| | |
| --- | --- |
| **Section** | S04 — State *(red line: **apply** a config with a secret → **inspect** state → **grep the plaintext secret** out of the file → **migrate** the backend → **break→fix** with `state rm` → **drift**: mutate the rendered file out-of-band and watch `plan` reconcile)* |
| **Environment** | `mock ✓ (no docker)` — no cloud, no Docker; uses the `random` + `local` providers only |
| **Estimated time** | 25 min |

## Objective

See **what state actually is** and why it matters — then see why it's dangerous.
You'll `apply` a small config that includes a **generated DB password**, inspect
the state with `tofu state list` / `show`, and then — the payoff — **`grep` that
password out of `terraform.tfstate` in plaintext**, even though the CLI redacts
it. That exposure is exactly what **S05 (state encryption)** closes.

Along the way you'll **migrate** the state to a new local path with
`tofu init -migrate-state` (the same mechanic you'd use to move to S3, no cloud
required), and run a **break→fix**: `tofu state rm` *forgets* a resource so the
next `plan` wants to recreate it — then `apply` reconciles. Finally you'll
**experience drift**: change the rendered manifest behind OpenTofu's back —
edit it, then delete it — and read the reconciling `plan` that steers reality
back to your config.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/04-state/`:

- `main.tf` — a three-resource config: a `random_password` (the secret), a
  `random_pet`, and the project's `local_file.manifest`, plus two outputs. This is
  the exact HCL S04 teaches; the slide's block is drift-checked to stay
  byte-identical to this file.
- `terraform.tfvars` — the auto-loaded `service` object and `environment`, carried
  forward from stage 5 so the lab runs non-interactively.

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

**Introduced here, and auxiliary:** the explicit `backend "local"` block (so Step
5 can migrate it) and `output "db_password"`, which keeps its own name because it
*is* the plaintext-in-state beat.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.
- `jq` and `grep` on `PATH` (both ship with macOS/Linux) — used to read the raw
  state JSON.
- Network access the first time (`tofu init` downloads the `random` + `local`
  providers). No Docker, no cloud, no AWS.
- Run everything **from the repo clone**.

## Files used

All tracked in `labs/day-1/04-state/` — you run them, you do not paste them:

- `main.tf` — the config: a `random_password`, a `random_pet`, the project's
  `local_file.manifest`, and two outputs, with an explicit `backend "local"` block
  so you can migrate it.
- `terraform.tfvars` — the auto-loaded `service` object and `environment`.
- `.gitignore` — keeps the state (which holds the **plaintext secret** — never
  commit it), `.terraform`, the rendered `out/` file, and the migrated `state/`
  dir out of version control.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/04-state
ls
```

**Task:** Confirm the config is already present — you author nothing (you only
*edit* the backend path later, and cleanup reverts it).

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf  terraform.tfvars
```

`main.tf` and `terraform.tfvars` are tracked in the repo. Everything below runs
against these exact files. (`.gitignore` is present too; `ls` hides dotfiles by
default.)
</details>

---

## Step 1 — Read the config: a secret, on purpose

`cat main.tf` and read it top to bottom. The point of interest is
`random_password.session`: a generated secret marked `sensitive` in its output.

<!-- source: labs/day-1/04-state/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }

  # State lives on the LOCAL backend by default. This explicit block names the
  # path so we can migrate it later with `tofu init -migrate-state`.
  backend "local" {
    path = "terraform.tfstate"
  }
}

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
grep -o '"result": "[^"]*"' terraform.tfstate
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
$ grep -o '"result": "[^"]*"' terraform.tfstate
"result": "MUH-Ud?RTW\u0026ven+_OcSC"

$ jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate
MUH-Ud?RTW&ven+_OcSC
```

The CLI is **polite** — `state show` prints `(sensitive value)`, which is
reassuring and **misleading**. `terraform.tfstate` is **plaintext JSON**: the
resolved password (`MUH-Ud?RTW&ven+_OcSC` here — **yours will be a completely
different random string**) sits in the file as a literal, and a one-line `grep`
exposes it. (In the raw JSON, `&` appears as its `\u0026` JSON unicode escape; `jq -r` decodes it back to `&`)

That file ends up in backups, CI artifacts, a stolen laptop, or an accidental
`git` commit — **anyone who reads the file reads your secret**. This is precisely
the risk **S05 — state encryption** closes: OpenTofu can encrypt state
client-side so what lands on disk is ciphertext, not this.
</details>

---

## Step 5 — Migrate the backend: `tofu init -migrate-state`

You switch where state lives by editing the `backend {}` block and re-initialising.
We can't stand up S3 here, so migrate between two **local paths** — the mechanic
is identical. Move the state into a `state/` subdirectory:

```bash
# edit the backend path in main.tf (a learner edit — cleanup reverts it)
sed -i.bak 's#path = "terraform.tfstate"#path = "state/terraform.tfstate"#' main.tf
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

## Cleanup / panic reset

Destroy the (local-only) resources, restore the tracked `main.tf`, and remove all
generated residue — including the state file that holds the plaintext secret. No
cloud resources exist, so nothing to bill or leak:

```bash
cd labs/day-1/04-state
tofu destroy -auto-approve                       # backend still points at the Step-5 state/ location
mv -f main.tf.bak main.tf 2>/dev/null || true    # revert the Step 5 backend edit
rm -rf .terraform .terraform.lock.hcl state out main.tf.bak
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # all root state incl. secret-bearing *.<ts>.backup (shell-agnostic)
git status --short .      # expect: no output
```

<details><summary>Expected output</summary>

```console
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
`out/` file, the migrated `state/` dir, and the `main.tf.bak` from Step 5 are all
gitignored or removed; the panic reset leaves the tracked `main.tf` and
`terraform.tfvars` exactly as CI verified them
(backend path back to `terraform.tfstate`). Order matters: `tofu destroy` runs
**before** reverting `main.tf`, so the backend still points at the migrated
`state/` location and the destroy actually removes the resources. The `find`
sweep catches every `terraform.tfstate*` in the root — including the timestamped
`.backup` that `tofu state rm` leaves — so no plaintext-secret file survives.
</details>

## Stretch (optional)

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
