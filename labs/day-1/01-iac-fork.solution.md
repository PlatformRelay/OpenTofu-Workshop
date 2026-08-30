# Lab 01 — From a shell script to HCL (and the fork story) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/01-iac-fork/` unless a step says otherwise.

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/01-iac-fork
ls
```

**Task:** Confirm the config is already present — you author nothing.

---

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf
```

`main.tf` is tracked in the repo. Everything below runs against this exact file.
(`.gitignore` is present too; `ls` hides dotfiles by default.)

</details>

---

### Step 1 — Feel the imperative pain first

Before the HCL, run the "click-ops in a script" version. Paste this throwaway
script and run it **twice**:

```bash
cat > /tmp/provision.sh <<'EOF'
#!/usr/bin/env bash
mkdir -p build
printf 'service = service-manifest\nenvironment = host-%s\n' "$RANDOM" > build/manifest.txt
cat build/manifest.txt
EOF
bash /tmp/provision.sh
bash /tmp/provision.sh
rm -rf build          # tidy up the scratch dir before the declarative run
```

**Task:** What is different between the two runs, and why is that a problem?

---

<details><summary>Solution / expected output</summary>

```console
$ bash /tmp/provision.sh
service = service-manifest
environment = host-26898
$ bash /tmp/provision.sh
service = service-manifest
environment = host-10428
```

The number is different every run — the script is **not idempotent**. It describes
*steps to take*, not *state to reach*, so "run it again" means "do it all again,
differently." There is no plan, no notion of "already done," and no way to detect
that someone changed the file afterwards. That's the gap declarative IaC closes.

</details>

---

### Step 2 — Read the declarative equivalent

Here is the HCL S01 teaches — the same intent ("a service manifest file exists"), expressed
as **desired state**. `cat` it so you read exactly what you're applying:

<!-- source: labs/day-1/01-iac-fork/main.tf -->
```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

# A stable, generated identity for this environment. The imperative script used
# $RANDOM; here the value is declared once and tracked in state, so every run is
# reproducible instead of different each time. AUXILIARY: it stands in for the
# environment name until stage 4 introduces the real variable "environment".
resource "random_pet" "env" {
  length = 2
}

# SPINE — the project starts here. local_file.manifest is the rendered service
# manifest every later Day-1 stage still declares; it is never renamed. The
# declarative equivalent of `printf ... > manifest.txt`: OpenTofu owns this file,
# creates it, detects drift if it changes, and destroys it on teardown.
resource "local_file" "manifest" {
  filename        = "${path.module}/build/manifest.txt"
  file_permission = "0644"
  content         = "service = service-manifest\nenvironment = ${random_pet.env.id}\n"
}

# SPINE — the manifest's path, surfaced under the name every later stage reuses.
output "manifest_path" {
  description = "Where the declaratively managed manifest landed."
  value       = local_file.manifest.filename
}
```

**Task:** Which block is the imperative `printf > file`, and which is the `$RANDOM`?

---

<details><summary>Solution</summary>

- `local_file.manifest` replaces `printf ... > build/manifest.txt` — but OpenTofu now
  *owns* the file: it will recreate it if it drifts and delete it on `destroy`.
- `random_pet.env` replaces `$RANDOM` — but the value is generated **once**, stored
  in state, and reused on every apply. That is the difference between "random each
  time" and "a stable generated identity."
- The top-level `terraform {}` block still carries that name for HCL compatibility,
  even though you run the `tofu` CLI. That naming is a direct legacy of the fork —
  see the licensing note below.

</details>

---

### Step 3 — `init`, then `plan` before you act

```bash
tofu init
tofu plan
```

**Task:** How many resources will be created, and what does `plan` give you that
the shell script never did?

---

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

### Step 4 — `apply` and prove idempotency

```bash
tofu apply -auto-approve
cat build/manifest.txt
tofu apply -auto-approve      # run it a SECOND time
```

**Task:** What does the **second** apply do?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
random_pet.env: Creating...
random_pet.env: Creation complete after 0s [id=arriving-duck]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=f6871a7f2900c1f64cd581acc5632f0b99b7fd24]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

manifest_path = "./build/manifest.txt"

$ cat build/manifest.txt
service = service-manifest
environment = arriving-duck
```

The **second** apply is a no-op — that's idempotency:

```console
$ tofu apply -auto-approve
random_pet.env: Refreshing state... [id=arriving-duck]
local_file.manifest: Refreshing state... [id=f6871a7f2900c1f64cd581acc5632f0b99b7fd24]

No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The generated pet name is stable across runs (it lives in state), so re-applying
changes nothing. The imperative script rolled a new number every time; declarative
IaC converges to the same desired state. (Your pet name will differ from
`arriving-duck` — it's generated once on the first apply.)

</details>

---

### Step 5 — Break → fix: drift detection

This is the payoff the shell script can never match. Tamper with the file OpenTofu
manages — simulate someone editing it by hand — then ask OpenTofu to look:

```bash
echo "hand-edited — someone SSHed in and changed it" > build/manifest.txt
tofu plan
```

**Task (break):** What does `plan` want to do, and why?

Now **fix** it — reconcile reality back to your declared desired state:

```bash
tofu apply -auto-approve
cat build/manifest.txt
```

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

So OpenTofu stays **MPL 2.0** (truly open source, Linux-Foundation-governed,
CNCF Sandbox since 2025-04-23) and keeps HCL compatibility — which is why the
block is still `terraform {}` but the CLI you run, and everything this workshop
teaches, is `tofu`.

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

## Stretch (optional)

- Add a second `local_file` that depends on the first (e.g. a `manifest.txt` listing
  the manifest path) and watch `plan` order the two by dependency.
- Change `random_pet`'s `length` from `2` to `3`, `plan`, and read how OpenTofu
  proposes to **replace** the pet and **update** the file that references it —
  a dependency graph doing its job.

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
random_pet.env: Refreshing state... [id=arriving-duck]
local_file.manifest: Refreshing state... [id=f6871a7f2900c1f64cd581acc5632f0b99b7fd24]

OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

OpenTofu will perform the following actions:

  # local_file.manifest will be created
  + resource "local_file" "manifest" {
      + content              = <<-EOT
            service = service-manifest
            environment = arriving-duck
        EOT
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

OpenTofu **refreshed** the real file, saw it no longer matches the recorded state,
and planned to put the managed content back. It detected the **drift** on its own.
An imperative script has no memory of what it did, so it could never notice.

</details>

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=f6871a7f2900c1f64cd581acc5632f0b99b7fd24]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

$ cat build/manifest.txt
service = service-manifest
environment = arriving-duck
```

The file is back to the declared content. **Config is the source of truth**;
`apply` makes the world match it again. That loop — declare, plan, apply, detect
drift, reconcile — is the whole reason IaC beats a pile of scripts.

</details>

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

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.manifest: Destroying... [id=f6871a7f2900c1f64cd581acc5632f0b99b7fd24]
local_file.manifest: Destruction complete after 0s
random_pet.env: Destroying... [id=arriving-duck]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

The generated state, `.terraform`, and `build/` are gitignored; the panic reset
leaves the tracked `main.tf` exactly as CI verified it.

</details>

---

## Expected state / output

- An imperative script describes **steps** and is **not idempotent** (new `$RANDOM`
  each run); declarative HCL describes **desired state** and converges to it.
- `tofu plan` previews changes **before** they happen — the shell script cannot.
- Re-applying an unchanged config is a **no-op** (idempotency).
- OpenTofu **detects drift** when a managed file is changed out-of-band and
  **reconciles** it back to the declared state on the next apply.
- The OpenTofu fork (BUSL relicense → 2023-08-25 fork → 1.6 GA) is why this
  workshop teaches the MPL-2.0-licensed `tofu` CLI, HCL-compatible with Terraform.

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

If a step fails mid-lab, prefer the documented panic reset before editing tracked files by hand:

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
local_file.manifest: Destroying... [id=f6871a7f2900c1f64cd581acc5632f0b99b7fd24]
local_file.manifest: Destruction complete after 0s
random_pet.env: Destroying... [id=arriving-duck]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

The generated state, `.terraform`, and `build/` are gitignored; the panic reset
leaves the tracked `main.tf` exactly as CI verified it.
</details>

Re-enter `labs/day-1/01-iac-fork/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- Add a second `local_file` that depends on the first (e.g. a `manifest.txt` listing
- Change `random_pet`'s `length` from `2` to `3`, `plan`, and read how OpenTofu

Example verification from the workdir:

```bash
cd labs/day-1/01-iac-fork
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
