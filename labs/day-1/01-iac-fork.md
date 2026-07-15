# Lab 01 — From a shell script to HCL (and the fork story)

| | |
| --- | --- |
| **Section** | S01 — Infrastructure as Code *(red line: **why IaC** → declarative → the OpenTofu fork)* |
| **Environment** | `mock ✓ (no docker)` — no cloud, no Docker; uses the `local` + `random` providers only |
| **Estimated time** | 20 min |

## Objective

Take a tiny **imperative** shell script that provisions a file and re-express it
as **declarative** HCL. Along the way you'll see the three things a shell script
can't give you for free: **idempotency**, a **plan** before you act, and **drift
detection** that reconciles reality back to your config. Then read the short
licensing note that explains why this workshop runs `tofu`, not `terraform`.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/01-iac-fork/`:

- `main.tf` — the declarative equivalent of the shell script: a `random_pet` for a
  stable generated identity plus a `local_file` OpenTofu fully owns (creates,
  drift-checks, destroys). This is the exact HCL S01 teaches; the slide and this
  file are drift-checked to stay byte-identical.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.
- Network access the first time (`tofu init` downloads the `local` + `random`
  providers from the registry). No Docker, no cloud, no AWS.
- Run everything **from the repo clone**.

## Files used

All tracked in `labs/day-1/01-iac-fork/` — you run them, you do not paste them:

- `main.tf` — the declarative provisioning config.
- `.gitignore` — keeps the state/`.terraform`/`build/` you generate out of version
  control.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/01-iac-fork
ls
```

**Task:** Confirm the config is already present — you author nothing.

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf
```

`main.tf` is tracked in the repo. Everything below runs against this exact file.
(`.gitignore` is present too; `ls` hides dotfiles by default.)
</details>

---

## Step 1 — Feel the imperative pain first

Before the HCL, run the "click-ops in a script" version. Paste this throwaway
script and run it **twice**:

```bash
cat > /tmp/provision.sh <<'EOF'
#!/usr/bin/env bash
mkdir -p build
echo "Hello from host-$RANDOM — provisioned imperatively." > build/greeting.txt
cat build/greeting.txt
EOF
bash /tmp/provision.sh
bash /tmp/provision.sh
rm -rf build          # tidy up the scratch dir before the declarative run
```

**Task:** What is different between the two runs, and why is that a problem?

<details><summary>Solution / expected output</summary>

```console
$ bash /tmp/provision.sh
Hello from host-26898 — provisioned imperatively.
$ bash /tmp/provision.sh
Hello from host-10428 — provisioned imperatively.
```

The number is different every run — the script is **not idempotent**. It describes
*steps to take*, not *state to reach*, so "run it again" means "do it all again,
differently." There is no plan, no notion of "already done," and no way to detect
that someone changed the file afterwards. That's the gap declarative IaC closes.
</details>

---

## Step 2 — Read the declarative equivalent

Here is the HCL S01 teaches — the same intent ("a greeting file exists"), expressed
as **desired state**. `cat` it so you read exactly what you're applying:

<!-- source: labs/day-1/01-iac-fork/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# A stable, generated identity for this environment. The imperative script used
# $RANDOM; here the value is declared once and tracked in state, so every run is
# reproducible instead of different each time.
resource "random_pet" "env" {
  length = 2
}

# The declarative equivalent of `echo ... > greeting.txt`. OpenTofu owns this
# file: it creates it, detects drift if it changes, and destroys it on teardown.
resource "local_file" "greeting" {
  filename        = "${path.module}/build/greeting.txt"
  file_permission = "0644"
  content         = "Hello from ${random_pet.env.id} — provisioned declaratively.\n"
}

output "greeting_path" {
  description = "Where the declaratively managed file landed."
  value       = local_file.greeting.filename
}
```

**Task:** Which block is the imperative `echo > file`, and which is the `$RANDOM`?

<details><summary>Solution</summary>

- `local_file.greeting` replaces `echo ... > build/greeting.txt` — but OpenTofu now
  *owns* the file: it will recreate it if it drifts and delete it on `destroy`.
- `random_pet.env` replaces `$RANDOM` — but the value is generated **once**, stored
  in state, and reused on every apply. That is the difference between "random each
  time" and "a stable generated identity."
- The top-level `terraform {}` block still carries that name for HCL compatibility,
  even though you run the `tofu` CLI. That naming is a direct legacy of the fork —
  see the licensing note below.

</details>

---

## Step 3 — `init`, then `plan` before you act

```bash
tofu init
tofu plan
```

**Task:** How many resources will be created, and what does `plan` give you that
the shell script never did?

<details><summary>Solution / expected output</summary>

```console
$ tofu init
- Installed hashicorp/local v2.9.0 (signed, key ID 0C0AF313E5FD9F80)
- Installed hashicorp/random v3.9.0 (signed, key ID 0C0AF313E5FD9F80)
...
OpenTofu has been successfully initialized!
```

`plan` shows `Plan: 2 to add, 0 to change, 0 to destroy.` — a `random_pet` and a
`local_file`. The point is the **preview itself**: you see exactly what will happen
*before* anything changes. The shell script just runs. (Provider versions may
differ as the registry moves; the count of 2 is what matters.)
</details>

---

## Step 4 — `apply` and prove idempotency

```bash
tofu apply -auto-approve
cat build/greeting.txt
tofu apply -auto-approve      # run it a SECOND time
```

**Task:** What does the **second** apply do?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
random_pet.env: Creating...
random_pet.env: Creation complete after 0s [id=arriving-duck]
local_file.greeting: Creating...
local_file.greeting: Creation complete after 0s [id=64e02644296e272730dab28ba3cef35ab26aa71d]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

greeting_path = "./build/greeting.txt"

$ cat build/greeting.txt
Hello from arriving-duck — provisioned declaratively.
```

The **second** apply is a no-op — that's idempotency:

```console
$ tofu apply -auto-approve
random_pet.env: Refreshing state... [id=arriving-duck]
local_file.greeting: Refreshing state... [id=64e02644296e272730dab28ba3cef35ab26aa71d]

No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The generated pet name is stable across runs (it lives in state), so re-applying
changes nothing. The imperative script rolled a new number every time; declarative
IaC converges to the same desired state. (Your pet name will differ from
`arriving-duck` — it's generated once on the first apply.)
</details>

---

## Step 5 — Break → fix: drift detection

This is the payoff the shell script can never match. Tamper with the file OpenTofu
manages — simulate someone editing it by hand — then ask OpenTofu to look:

```bash
echo "hand-edited — someone SSHed in and changed it" > build/greeting.txt
tofu plan
```

**Task (break):** What does `plan` want to do, and why?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
random_pet.env: Refreshing state... [id=arriving-duck]
local_file.greeting: Refreshing state... [id=64e02644296e272730dab28ba3cef35ab26aa71d]

OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

OpenTofu will perform the following actions:

  # local_file.greeting will be created
  + resource "local_file" "greeting" {
      + content              = <<-EOT
            Hello from arriving-duck — provisioned declaratively.
        EOT
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

OpenTofu **refreshed** the real file, saw it no longer matches the recorded state,
and planned to put the managed content back. It detected the **drift** on its own.
An imperative script has no memory of what it did, so it could never notice.
</details>

Now **fix** it — reconcile reality back to your declared desired state:

```bash
tofu apply -auto-approve
cat build/greeting.txt
```

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
local_file.greeting: Creating...
local_file.greeting: Creation complete after 0s [id=64e02644296e272730dab28ba3cef35ab26aa71d]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

$ cat build/greeting.txt
Hello from arriving-duck — provisioned declaratively.
```

The file is back to the declared content. **Config is the source of truth**;
`apply` makes the world match it again. That loop — declare, plan, apply, detect
drift, reconcile — is the whole reason IaC beats a pile of scripts.
</details>

---

## The fork & licensing note (read this)

Why does this lab run `tofu` and not `terraform`, when the top-level block is still
called `terraform {}`?

- **2023-08-10** — HashiCorp relicensed Terraform from the open-source **MPL 2.0**
  to the **BUSL 1.1** (Business Source License), a source-available licence that
  restricts competing commercial use.
- **2023-08-25** — the community forked the last MPL-2.0 Terraform as **OpenTofu**.
- **2024-01-10** — **OpenTofu 1.6** shipped as a stable, drop-in-compatible GA,
  now governed by the **Linux Foundation**.

So OpenTofu stays **MPL 2.0** (truly open source, Linux-Foundation-governed) and
keeps HCL compatibility — which is why the block is still `terraform {}` but the
CLI you run, and everything this workshop teaches, is `tofu`.

<details><summary>Question: what does the MPL-2.0-vs-BUSL-1.1 difference mean for you?</summary>

**MPL 2.0** (OpenTofu) is a permissive open-source licence: you can use, modify, and
build a product on it, including commercially, with no field-of-use limit.
**BUSL 1.1** (Terraform, post-2023) is *source-available*, not open source: the code
is visible, but its "additional use grant" forbids using it to compete with the
licensor's commercial products until each release's change-date converts to an
older open licence. For a team that wants a genuinely open, community-governed tool
with no competitive-use restriction, OpenTofu under MPL 2.0 is the answer — and it's
CLI- and HCL-compatible, so migrating is low-friction.
</details>

## Expected observations

- An imperative script describes **steps** and is **not idempotent** (new `$RANDOM`
  each run); declarative HCL describes **desired state** and converges to it.
- `tofu plan` previews changes **before** they happen — the shell script cannot.
- Re-applying an unchanged config is a **no-op** (idempotency).
- OpenTofu **detects drift** when a managed file is changed out-of-band and
  **reconciles** it back to the declared state on the next apply.
- The OpenTofu fork (BUSL relicense → 2023-08-25 fork → 1.6 GA) is why this
  workshop teaches the MPL-2.0-licensed `tofu` CLI, HCL-compatible with Terraform.

## Cleanup / panic reset

Destroy the (local-only) resources and remove all generated residue — no cloud
resources exist, so nothing to bill or leak:

```bash
cd labs/day-1/01-iac-fork
tofu destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* build
rm -f /tmp/provision.sh
git status --short labs/day-1/01-iac-fork      # expect: no output
```

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.greeting: Destroying... [id=64e02644296e272730dab28ba3cef35ab26aa71d]
local_file.greeting: Destruction complete after 0s
random_pet.env: Destroying... [id=arriving-duck]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

The generated state, `.terraform`, and `build/` are gitignored; the panic reset
leaves the tracked `main.tf` exactly as CI verified it.
</details>

## Stretch (optional)

- Add a second `local_file` that depends on the first (e.g. a `manifest.txt` listing
  the greeting path) and watch `plan` order the two by dependency.
- Change `random_pet`'s `length` from `2` to `3`, `plan`, and read how OpenTofu
  proposes to **replace** the pet and **update** the file that references it —
  a dependency graph doing its job.
