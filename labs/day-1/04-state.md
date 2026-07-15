# Lab 04 — read and steer state (list / show / mv / rm + a plaintext secret)

| | |
| --- | --- |
| **Section** | S04 — State *(red line: **apply** a config with a secret → **inspect** state → **grep the plaintext secret** out of the file → **migrate** the backend → **break→fix** with `state rm`)* |
| **Environment** | `mock ✓ (no docker)` — no cloud, no Docker; uses the `random` + `local` providers only |
| **Estimated time** | 20 min |

## Objective

See **what state actually is** and why it matters — then see why it's dangerous.
You'll `apply` a small config that includes a **generated DB password**, inspect
the state with `tofu state list` / `show`, and then — the payoff — **`grep` that
password out of `terraform.tfstate` in plaintext**, even though the CLI redacts
it. That exposure is exactly what **S05 (state encryption)** closes.

Along the way you'll **migrate** the state to a new local path with
`tofu init -migrate-state` (the same mechanic you'd use to move to S3, no cloud
required), and run a **break→fix**: `tofu state rm` *forgets* a resource so the
next `plan` wants to recreate it — then `apply` reconciles.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/04-state/`:

- `main.tf` — a three-resource config: a `random_password` (the secret), a
  `random_pet`, and a `local_file`, plus two outputs. This is the exact HCL S04
  teaches; the slide's block is drift-checked to stay byte-identical to this file.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.
- `jq` and `grep` on `PATH` (both ship with macOS/Linux) — used to read the raw
  state JSON.
- Network access the first time (`tofu init` downloads the `random` + `local`
  providers). No Docker, no cloud, no AWS.
- Run everything **from the repo clone**.

## Files used

All tracked in `labs/day-1/04-state/` — you run them, you do not paste them:

- `main.tf` — the config: a `random_password`, a `random_pet`, a `local_file`,
  and two outputs, with an explicit `backend "local"` block so you can migrate it.
- `.gitignore` — keeps the state (which holds the **plaintext secret** — never
  commit it), `.terraform`, `build/`, and the migrated `state/` dir out of
  version control.

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
main.tf
```

`main.tf` is tracked in the repo. Everything below runs against this exact file.
(`.gitignore` is present too; `ls` hides dotfiles by default.)
</details>

---

## Step 1 — Read the config: a secret, on purpose

`cat main.tf` and read it top to bottom. The point of interest is
`random_password.db`: a generated secret marked `sensitive` in its output.

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

# A generated database password. It is `sensitive`, so tofu redacts it in CLI
# output — but the RESOLVED value is still written to terraform.tfstate as
# plaintext JSON. That gap is exactly what S05 (state encryption) closes.
resource "random_password" "db" {
  length  = 20
  special = true
}

# A plain resource so `state list` has more than one entry to show, mv, and rm.
resource "random_pet" "service" {
  length = 2
}

# Records the service name (not the secret) to a file — state also stores this.
resource "local_file" "service_name" {
  filename = "${path.module}/build/service.txt"
  content  = "service = ${random_pet.service.id}\n"
}

output "service_name" {
  description = "The generated service name (safe to print)."
  value       = random_pet.service.id
}

output "db_password" {
  description = "The generated DB password — sensitive, so redacted in CLI output."
  value       = random_password.db.result
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
  + db_password  = (sensitive value)
  + service_name = (known after apply)
random_pet.service: Creating...
random_password.db: Creating...
random_pet.service: Creation complete after 0s [id=crack-parrot]
local_file.service_name: Creating...
local_file.service_name: Creation complete after 0s [id=0bada648b1f53bed86a57e6183f2188f2935f9f7]
random_password.db: Creation complete after 0s [id=none]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

db_password = <sensitive>
service_name = "crack-parrot"
```

The output prints `db_password = <sensitive>` — OpenTofu **redacts** it because
the output is `sensitive`. (`Resources: 3 added` — the `random_password`, the
`random_pet`, and the `local_file`; `db_password` and `service_name` are
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
tofu state show random_pet.service
```

**Task:** What does `state list` return, and what is `state show` good for?

<details><summary>Solution / expected output</summary>

```console
$ tofu state list
local_file.service_name
random_password.db
random_pet.service

$ tofu state show random_pet.service
# random_pet.service:
resource "random_pet" "service" {
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
tofu state show random_password.db | grep result
grep -o '"result": "[^"]*"' terraform.tfstate
jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate
```

**Question:** Does `tofu state show random_password.db` reveal the password? Where
*is* the plaintext password, and what does that mean for anyone who can read the
file?

<details><summary>Spoiler — the plaintext secret, verbatim</summary>

`state show` **redacts** it — the CLI honours `sensitive`:

```console
$ tofu state show random_password.db | grep result
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
random_pet.service: Refreshing state... [id=crack-parrot]
...
No changes. Your infrastructure matches the configuration.
```

</details>

---

## Step 6 — Break → fix: `state rm` forgets a resource

`tofu state rm` removes a resource from state **without destroying the real
thing**. That's a sharp edge — do it on purpose and watch what breaks.

```bash
tofu state rm random_pet.service
tofu state list
tofu plan
```

**Task (break):** After `state rm random_pet.service`, what does `state list`
show, and what does the next `plan` want to do — and *why*?

<details><summary>Solution / expected output</summary>

```console
$ tofu state rm random_pet.service
Removed random_pet.service
Successfully removed 1 resource instance(s).

$ tofu state list
local_file.service_name
random_password.db

$ tofu plan
...
Plan: 2 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  ~ service_name = "crack-parrot" -> (known after apply)
```

`random_pet.service` is **gone from state** — but the config still declares it.
So OpenTofu now believes the pet doesn't exist and plans to **create** it
(`2 to add`: the pet, plus a re-created `service.txt` whose content references the
new pet id; `1 to destroy`: the stale file). `state rm` **forgets**, it does not
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
random_pet.service: Creating...
random_pet.service: Creation complete after 0s [id=fleet-kite]
local_file.service_name: Creating...
local_file.service_name: Creation complete after 0s [id=ae4ca3aa05c950ffc9a72f1582d0eed5db0777cb]

Apply complete! Resources: 2 added, 0 changed, 1 destroyed.

Outputs:

db_password = <sensitive>
service_name = "fleet-kite"

$ tofu state list
local_file.service_name
random_password.db
random_pet.service
```

`apply` reconciles: it re-creates the forgotten `random_pet.service` and rewrites
the file, so `state list` shows all three again. Note the pet name **changed**
(`crack-parrot` → `fleet-kite` here — yours will differ): because state *forgot*
the old pet, OpenTofu generated a **fresh** one rather than reusing the old value.
That's the lesson — state is what preserves generated values across runs; lose the
state entry and you lose the value. (The `db_password` was untouched — it was
never `rm`'d — so it kept its value.)
</details>

## Expected observations

- **State is the map** from config addresses (`random_pet.service`) to real
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

## Cleanup / panic reset

Destroy the (local-only) resources, restore the tracked `main.tf`, and remove all
generated residue — including the state file that holds the plaintext secret. No
cloud resources exist, so nothing to bill or leak:

```bash
cd labs/day-1/04-state
tofu destroy -auto-approve                       # backend still points at the Step-5 state/ location
mv -f main.tf.bak main.tf 2>/dev/null || true    # revert the Step 5 backend edit
rm -rf .terraform .terraform.lock.hcl state build main.tf.bak
find . -maxdepth 1 -name 'terraform.tfstate*' -delete   # all root state incl. secret-bearing *.<ts>.backup (shell-agnostic)
git status --short .      # expect: no output
```

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
random_password.db: Destroying... [id=none]
random_password.db: Destruction complete after 0s
local_file.service_name: Destroying... [id=ae4ca3aa05c950ffc9a72f1582d0eed5db0777cb]
local_file.service_name: Destruction complete after 0s
random_pet.service: Destroying... [id=fleet-kite]
random_pet.service: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

The generated state (with its plaintext secret), `.terraform`, `build/`, the
migrated `state/` dir, and the `main.tf.bak` from Step 5 are all gitignored or
removed; the panic reset leaves the tracked `main.tf` exactly as CI verified it
(backend path back to `terraform.tfstate`). Order matters: `tofu destroy` runs
**before** reverting `main.tf`, so the backend still points at the migrated
`state/` location and the destroy actually removes the resources. The `find`
sweep catches every `terraform.tfstate*` in the root — including the timestamped
`.backup` that `tofu state rm` leaves — so no plaintext-secret file survives.
</details>

## Stretch (optional)

- Rename the resource cleanly with `state mv`. Rename it **everywhere in `main.tf`** —
  the block label `random_pet "service"` **and both references** to it
  (`random_pet.service.id` in `local_file.service_name`'s `content`, and in
  `output "service_name"`) → `svc`. Then run `tofu state mv random_pet.service
  random_pet.svc` **before** planning. The `plan` is then a no-op — you renamed
  the *address* in both config and state, so OpenTofu keeps the same real object
  instead of destroy-recreating it. (Skip the `state mv` and `plan` shows
  `1 to add, 1 to destroy` — the rename becomes a replacement.)

  <details><summary>Solution / expected output (the state-only rename)</summary>

  ```console
  $ tofu state mv random_pet.service random_pet.svc
  Move "random_pet.service" to "random_pet.svc"
  Successfully moved 1 object(s).
  ```

  With the config fully renamed to `random_pet "svc"` — the block **and** both
  references — the address in state and the address in config match again, so
  `tofu plan` reports `No changes`. `state mv` is the tool for refactoring a
  resource's *address* without touching the real resource. Restore `"service"`
  everywhere afterwards, or run the panic reset.
  </details>
- Inspect the whole state as JSON with `tofu show -json | jq` and find every
  `sensitive_values` block — OpenTofu *marks* which attributes are sensitive, but
  still stores their plaintext right beside the marker. That contrast is the whole
  argument for S05.
