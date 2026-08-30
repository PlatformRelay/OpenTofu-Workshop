# Lab 03 — the core workflow (init / plan / apply / destroy) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/03-core-workflow/` unless a step says otherwise.

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/03-core-workflow
ls
```

**Task:** Confirm the config is already present — you author nothing (until the
break→fix, where you add one scratch file).

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

### Step 1 — Read the config and its dependency chain

`cat main.tf` and read it top to bottom. It is deliberately small, but its
references form a **chain**: the pet must exist before the manifest, and the
manifest before the summary.

<!-- source: labs/day-1/03-core-workflow/main.tf -->
```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

provider "local" {}

# AUXILIARY, carried under the same address as stages 1-2: random_pet.env.
# Created once and stored in state, so every apply reuses it — the anchor the
# rest of the graph depends on.
resource "random_pet" "env" {
  length = 2
}

# SPINE — local_file.manifest, carried forward from stage 2. Depends on
# random_pet.env: the reference below makes OpenTofu create the pet FIRST, then
# this file. That edge is one arc of the dependency graph plan orders for you.
resource "local_file" "manifest" {
  filename = "${path.module}/build/manifest.txt"
  content  = "environment = ${random_pet.env.id}\n"
}

# AUXILIARY — a second graph node, and nothing more. It depends on
# local_file.manifest: it reads the manifest's content back, so this file can
# only be written AFTER the manifest exists. Two edges, one clear order. Its
# teaching job ends with this stage; stage 4 retires it.
resource "local_file" "summary" {
  filename = "${path.module}/build/summary.txt"
  content  = "Deployed ${trimspace(local_file.manifest.content)} via the core workflow.\n"
}

# SPINE — output manifest_path, carried forward from stage 2.
output "manifest_path" {
  description = "Where the rendered manifest landed."
  value       = local_file.manifest.filename
}
```

**Task:** Draw the dependency edges. Which resource must OpenTofu create first,
and which last — and *why*?

---

<details><summary>Solution</summary>

The references define the graph:

```text
random_pet.env  →  local_file.manifest  →  local_file.summary
```

- `local_file.manifest` reads `random_pet.env.id`, so the **pet must exist
  first**.
- `local_file.summary` reads `local_file.manifest.content`, so the **manifest
  must exist before the summary**.

OpenTofu builds this graph from the references — **not** from the order the
blocks appear in the file. Create order is `env` → `manifest` → `summary`;
`destroy` runs it in **reverse**. You never declare the order yourself; the graph
does.

</details>

---

### Step 2 — `init`: providers and the lock file

`init` is the first command in every workflow. It prepares the working directory:
it installs the providers your config requires and writes a **lock file**.

```bash
tofu init
cat .terraform.lock.hcl
```

**Task:** What did `init` download, and what is `.terraform.lock.hcl` for — should
you commit it?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu init

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/random...
- Finding latest version of hashicorp/local...
- Installing hashicorp/random v3.9.0...
- Installing hashicorp/local v2.9.0...
- Installed hashicorp/random v3.9.0 (signed, key ID 0C0AF313E5FD9F80)
- Installed hashicorp/local v2.9.0 (signed, key ID 0C0AF313E5FD9F80)

OpenTofu has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
...
OpenTofu has been successfully initialized!
```

`init` installed the two providers `main.tf` requires (`local`, `random`) into
`.terraform/` and wrote `.terraform.lock.hcl` pinning their exact versions and
checksums:

```console
$ cat .terraform.lock.hcl
# This file is maintained automatically by "tofu init".
# Manual edits may be lost in future updates.

provider "registry.opentofu.org/hashicorp/local" {
  version = "2.9.0"
  hashes = [
    "h1:1dtKYW/5a1qob3yneL6WzOlnSGfYtJ6a2XeejCk9yb4=",
    ...
  ]
}

provider "registry.opentofu.org/hashicorp/random" {
  version = "3.9.0"
  ...
}
```

**Yes — commit it.** The lock file guarantees that everyone (and CI) resolves the
**same** provider versions and verifies them against the recorded checksums. It is
OpenTofu's `package-lock.json`. (Your versions may be newer as the registry moves;
the point is that they are now *pinned* for this repo.)

</details>

---

### Step 3 — `plan`: read the execution plan

`plan` computes the diff between your config and reality (here, empty state) and
prints it — **without changing anything**.

```bash
tofu plan
```

**Task:** What do the `+` symbol, `(known after apply)`, and the final
`Plan: 3 to add …` line each mean?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

OpenTofu will perform the following actions:

  # local_file.manifest will be created
  + resource "local_file" "manifest" {
      + content              = (known after apply)
      ...
      + filename             = "./build/manifest.txt"
      + id                   = (known after apply)
    }

  # local_file.summary will be created
  + resource "local_file" "summary" {
      ...
    }

  # random_pet.env will be created
  + resource "random_pet" "env" {
      + id        = (known after apply)
      + length    = 2
      + separator = "-"
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + manifest_path = "./build/manifest.txt"
```

- **`+ create`** — each resource is new. The plan legend at the top names every
  symbol it will use.
- **`(known after apply)`** — a value OpenTofu can't compute yet because it comes
  from a resource that doesn't exist. The pet's `id`, and everything that
  references it (`manifest.content`, the summary's content), resolve only *after*
  apply. Contrast `manifest_path`: it reads the manifest's `filename`, which is a
  literal in the config, so the plan can already print its value.
- **`Plan: 3 to add, 0 to change, 0 to destroy.`** — the one-line summary: the
  `random_pet` plus the two `local_file`s. Reading this line first, then scanning
  the symbols, is how you review any plan. (The plan is a **preview** — nothing on
  disk changed.)

</details>

---

### Step 4 — `apply`: converge, and watch the ordering

`apply` re-runs the plan and then executes it, creating resources **in dependency
order**.

```bash
tofu apply -auto-approve
cat build/manifest.txt build/summary.txt
```

**Task:** In what order were the three resources created, and does that match the
graph you drew in Step 1?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + manifest_path = "./build/manifest.txt"
random_pet.env: Creating...
random_pet.env: Creation complete after 0s [id=firm-jackal]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=0ac42dc11a96850f22e26aee50136aaa6d4865f0]
local_file.summary: Creating...
local_file.summary: Creation complete after 0s [id=06ab671c8f091a7a4aad2da0229b777664762b6d]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

manifest_path = "./build/manifest.txt"

$ cat build/manifest.txt build/summary.txt
environment = firm-jackal
Deployed environment = firm-jackal via the core workflow.
```

Creation order is **`random_pet.env` → `local_file.manifest` →
`local_file.summary`** — exactly the graph from Step 1. OpenTofu created the pet
first because the manifest references it, then the manifest before the summary.
The generated pet name (`firm-jackal` here — **yours will differ**) flowed through
every reference: into the manifest, and from there into the summary. The
`manifest_path` output surfaces where the manifest landed.

</details>

---

### Step 5 — Idempotency: apply again, change nothing

The defining property of declarative IaC: re-running an unchanged config does
**nothing**.

```bash
tofu apply -auto-approve
```

**Task:** What does the **second** apply do, and why is that the whole point?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
random_pet.env: Refreshing state... [id=firm-jackal]
local_file.manifest: Refreshing state... [id=0ac42dc11a96850f22e26aee50136aaa6d4865f0]
local_file.summary: Refreshing state... [id=06ab671c8f091a7a4aad2da0229b777664762b6d]

No changes. Your infrastructure matches the configuration.

OpenTofu has compared your real infrastructure against your configuration and
found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

`0 added, 0 changed, 0 destroyed` — a **no-op**. OpenTofu refreshed the real
resources, compared them to the config, found no drift, and did nothing. The pet
name is stable because it lives in state, so nothing is regenerated. That is
**idempotency**: the outcome depends on the desired state, not on how many times
you run. An imperative script would have rolled a new value and rewritten the
files every run.

</details>

---

### Step 6 — Break → fix: a dependency cycle

The dependency graph must be **acyclic** — A can depend on B, or B on A, but not
both. Create that impossible situation on purpose in a **scratch** file
(`broken.tf`) so `main.tf` stays pristine:

```bash
cat > broken.tf <<'EOF'
resource "local_file" "ping" {
  filename = "${path.module}/build/ping.txt"
  content  = "pong says: ${local_file.pong.content}"
}

resource "local_file" "pong" {
  filename = "${path.module}/build/pong.txt"
  content  = "ping says: ${local_file.ping.content}"
}
EOF
tofu plan
```

**Task (break):** Why does `plan` fail — what does the graph look like, and what
does OpenTofu report?

Now **fix** it — break the cycle so the edge points one way only:

```bash
cat > broken.tf <<'EOF'
resource "local_file" "ping" {
  filename = "${path.module}/build/ping.txt"
  content  = "pong says: ${local_file.pong.content}"
}

resource "local_file" "pong" {
  filename = "${path.module}/build/pong.txt"
  content  = "a standalone message"
}
EOF
tofu plan
```

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan

Error: Cycle: local_file.ping, local_file.pong
```

Each file references the *other's* content, so the graph has an edge `ping → pong`
**and** `pong → ping`:

```text
local_file.ping  ⇄  local_file.pong      (a cycle — no valid order)
```

OpenTofu must create `ping` before `pong` (ping reads pong) *and* `pong` before
`ping` (pong reads ping) — impossible. It detects the loop while building the
graph and **refuses to plan**, naming the two resources in the cycle. Nothing was
created; a cyclic reference is a config error, caught before any change.

</details>

<details><summary>Solution / expected output</summary>

```console
$ tofu plan
...
  # local_file.ping will be created
  + resource "local_file" "ping" {
      + content              = "pong says: a standalone message"
      ...
    }

  # local_file.pong will be created
  + resource "local_file" "pong" {
      + content              = "a standalone message"
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

`pong` no longer references `ping`, so the graph is a directed **acyclic** graph —
just `ping → pong`. OpenTofu can now order it (`pong` first, then `ping`) and
`plan` succeeds: `Plan: 2 to add`. **The graph must be acyclic** — that is the rule
the error was enforcing. You do not need to `apply` this; the point was the break
and the fix. Remove the scratch file in cleanup.

</details>

---

### Step 7 — `destroy`: tear it down in reverse

`destroy` is the last command in the lifecycle: it removes everything in state,
in **reverse** dependency order.

```bash
rm -f broken.tf
tofu destroy -auto-approve
```

**Task:** What does the `-` symbol mean, and why is the destroy order the reverse
of the create order?

## Expected observations

- `init` installs the required providers and writes **`.terraform.lock.hcl`**,
  which pins versions + checksums and **is committed**.
- A **plan** is a preview: `+` create, `~` update/replace, `-` destroy, plus
  `(known after apply)` for values that only exist post-apply, summarised by
  `Plan: N to add, N to change, N to destroy.`
- **`apply`** converges reality to the config, creating resources in **dependency
  order**; a second `apply` is a **no-op** (idempotency).
- The **dependency graph** — built from references, not file order — decides
  create order and reverses it for `destroy`.
- A **dependency cycle** fails with `Error: Cycle: …`; breaking the two-way
  reference makes the graph acyclic and lets `plan` succeed again.

## Cleanup / panic reset

Destroy the (local-only) resources and remove all generated residue — no cloud
resources exist, so nothing to bill or leak:

```bash
cd labs/day-1/03-core-workflow
rm -f broken.tf
tofu destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* build
git status --short .      # expect: no output
```

## Stretch (optional)

- Change `random_pet`'s `length` from `2` to `3`, run `tofu plan`, and read how
  OpenTofu proposes `-/+ destroy and then create replacement` with `~ … # forces
  replacement` — and how that **cascades** through the manifest and summary that
  reference it. That's the `~` symbol and the graph, together.

- Run `tofu apply` with `-out=tfplan` to save the plan, then `tofu apply tfplan`
  to apply exactly that saved plan — the safe two-step review flow.
- Run `tofu graph` and paste the output into a Graphviz viewer to *see* the
  dependency DAG you drew by hand in Step 1.

<details><summary>Solution / expected output</summary>

```console
$ tofu destroy -auto-approve
...
OpenTofu will perform the following actions:

  # local_file.manifest will be destroyed
  - resource "local_file" "manifest" {
      ...
    }
  # local_file.summary will be destroyed
  - resource "local_file" "summary" {
      ...
    }
  # random_pet.env will be destroyed
  - resource "random_pet" "env" {
      - id        = "firm-jackal" -> null
      ...
    }

Plan: 0 to add, 0 to change, 3 to destroy.
...
local_file.summary: Destroying... [id=06ab671c8f091a7a4aad2da0229b777664762b6d]
local_file.summary: Destruction complete after 0s
local_file.manifest: Destroying... [id=0ac42dc11a96850f22e26aee50136aaa6d4865f0]
local_file.manifest: Destruction complete after 0s
random_pet.env: Destroying... [id=firm-jackal]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

- **`- destroy`** — each resource is being removed (attributes shown going
  `-> null`).
- Destruction order is **`summary` → `manifest` → `env`** — the **reverse** of
  create order. OpenTofu tears down dependents before their dependencies, so it
  never deletes something another resource still needs. The graph orders both
  directions for you. (If you removed `broken.tf` before this step, the plan is
  `3 to destroy`; if `ping`/`pong` were still applied it would be more.)

</details>

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.summary: Destroying... [id=06ab671c8f091a7a4aad2da0229b777664762b6d]
local_file.summary: Destruction complete after 0s
local_file.manifest: Destroying... [id=0ac42dc11a96850f22e26aee50136aaa6d4865f0]
local_file.manifest: Destruction complete after 0s
random_pet.env: Destroying... [id=firm-jackal]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

The generated state, `.terraform`, `build/`, and the scratch `broken.tf` are all
gitignored or removed; the panic reset leaves the tracked `main.tf` exactly as CI
verified it.

</details>

---

## Expected state / output

- `init` installs the required providers and writes **`.terraform.lock.hcl`**,
  which pins versions + checksums and **is committed**.
- A **plan** is a preview: `+` create, `~` update/replace, `-` destroy, plus
  `(known after apply)` for values that only exist post-apply, summarised by
  `Plan: N to add, N to change, N to destroy.`
- **`apply`** converges reality to the config, creating resources in **dependency
  order**; a second `apply` is a **no-op** (idempotency).
- The **dependency graph** — built from references, not file order — decides
  create order and reverses it for `destroy`.
- A **dependency cycle** fails with `Error: Cycle: …`; breaking the two-way
  reference makes the graph acyclic and lets `plan` succeed again.

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
cd labs/day-1/03-core-workflow
rm -f broken.tf
tofu destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* build
git status --short .      # expect: no output
```

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.summary: Destroying... [id=06ab671c8f091a7a4aad2da0229b777664762b6d]
local_file.summary: Destruction complete after 0s
local_file.manifest: Destroying... [id=0ac42dc11a96850f22e26aee50136aaa6d4865f0]
local_file.manifest: Destruction complete after 0s
random_pet.env: Destroying... [id=firm-jackal]
random_pet.env: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

The generated state, `.terraform`, `build/`, and the scratch `broken.tf` are all
gitignored or removed; the panic reset leaves the tracked `main.tf` exactly as CI
verified it.
</details>

Re-enter `labs/day-1/03-core-workflow/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- Change `random_pet`'s `length` from `2` to `3`, run `tofu plan`, and read how
- Run `tofu apply` with `-out=tfplan` to save the plan, then `tofu apply tfplan`
- Run `tofu graph` and paste the output into a Graphviz viewer to *see* the

Example verification from the workdir:

```bash
cd labs/day-1/03-core-workflow
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
