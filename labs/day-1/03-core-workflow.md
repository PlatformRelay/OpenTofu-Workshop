# Lab 03 — the core workflow (init / plan / apply / destroy)

| | |
| --- | --- |
| **Section** | S03 — Core workflow *(red line: **init** → read a **plan** → **apply** → **destroy** → the **dependency graph** → a cycle break→fix)* |
| **Environment** | `mock ✓ (no docker)` — no cloud, no Docker; uses the `local` + `random` providers only |
| **Estimated time** | 20 min |

## Objective

Run the entire OpenTofu lifecycle end to end — `init`, `plan`, `apply`,
`destroy` — against one small config, and **learn to read an execution plan**:
the `+` / `~` / `-` symbols, `Plan: N to add …`, and `(known after apply)`. Along
the way you'll see the **dependency graph** decide creation order, prove that a
second `apply` is a **no-op** (idempotency), and force a real **dependency cycle**
so `tofu` refuses to plan — then fix it.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/03-core-workflow/`:

- `main.tf` — a three-resource config whose references form a clear dependency
  chain (`random_pet` → `manifest` → `summary`). This is the exact HCL S03
  teaches; the slide's block is drift-checked to stay byte-identical to this file.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.
- Network access the first time (`tofu init` downloads the `local` + `random`
  providers from the registry). No Docker, no cloud, no AWS.
- Run everything **from the repo clone**.

## Files used

All tracked in `labs/day-1/03-core-workflow/` — you run them, you do not paste them:

- `main.tf` — the config: a `random_pet` and two `local_file` resources wired by
  references into a dependency chain, plus an `output`.
- `.gitignore` — keeps the state / `.terraform` / `build/` you generate (and the
  scratch `broken.tf` from Step 6) out of version control.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/03-core-workflow
ls
```

**Task:** Confirm the config is already present — you author nothing (until the
break→fix, where you add one scratch file).

<details><summary>Solution / expected output</summary>

```console
$ ls
main.tf
```

`main.tf` is tracked in the repo. Everything below runs against this exact file.
(`.gitignore` is present too; `ls` hides dotfiles by default.)
</details>

---

## Step 1 — Read the config and its dependency chain

`cat main.tf` and read it top to bottom. It is deliberately small, but its
references form a **chain**: the pet must exist before the manifest, and the
manifest before the summary.

<!-- source: labs/day-1/03-core-workflow/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
  required_providers {
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

provider "local" {}

# A stable, generated release name. Created once and stored in state, so every
# apply reuses it — the anchor the rest of the graph depends on.
resource "random_pet" "release" {
  length = 2
}

# Depends on random_pet.release: the reference below makes OpenTofu create the
# pet FIRST, then this file. That edge is one arc of the dependency graph plan
# orders for you.
resource "local_file" "manifest" {
  filename = "${path.module}/build/manifest.txt"
  content  = "release = ${random_pet.release.id}\n"
}

# Depends on local_file.manifest: it reads the manifest's content back, so this
# file can only be written AFTER the manifest exists. Two edges, one clear order.
resource "local_file" "summary" {
  filename = "${path.module}/build/summary.txt"
  content  = "Deployed ${trimspace(local_file.manifest.content)} via the core workflow.\n"
}

output "release_name" {
  description = "The generated release name recorded in the manifest."
  value       = random_pet.release.id
}
```

**Task:** Draw the dependency edges. Which resource must OpenTofu create first,
and which last — and *why*?

<details><summary>Solution</summary>

The references define the graph:

```text
random_pet.release  →  local_file.manifest  →  local_file.summary
```

- `local_file.manifest` reads `random_pet.release.id`, so the **pet must exist
  first**.
- `local_file.summary` reads `local_file.manifest.content`, so the **manifest
  must exist before the summary**.

OpenTofu builds this graph from the references — **not** from the order the
blocks appear in the file. Create order is `release` → `manifest` → `summary`;
`destroy` runs it in **reverse**. You never declare the order yourself; the graph
does.
</details>

---

## Step 2 — `init`: providers and the lock file

`init` is the first command in every workflow. It prepares the working directory:
it installs the providers your config requires and writes a **lock file**.

```bash
tofu init
cat .terraform.lock.hcl
```

**Task:** What did `init` download, and what is `.terraform.lock.hcl` for — should
you commit it?

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

## Step 3 — `plan`: read the execution plan

`plan` computes the diff between your config and reality (here, empty state) and
prints it — **without changing anything**.

```bash
tofu plan
```

**Task:** What do the `+` symbol, `(known after apply)`, and the final
`Plan: 3 to add …` line each mean?

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

  # random_pet.release will be created
  + resource "random_pet" "release" {
      + id        = (known after apply)
      + length    = 2
      + separator = "-"
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + release_name = (known after apply)
```

- **`+ create`** — each resource is new. The plan legend at the top names every
  symbol it will use.
- **`(known after apply)`** — a value OpenTofu can't compute yet because it comes
  from a resource that doesn't exist. The pet's `id`, and everything that
  references it (`manifest.content`, `release_name`), resolve only *after* apply.
- **`Plan: 3 to add, 0 to change, 0 to destroy.`** — the one-line summary: the
  `random_pet` plus the two `local_file`s. Reading this line first, then scanning
  the symbols, is how you review any plan. (The plan is a **preview** — nothing on
  disk changed.)

</details>

---

## Step 4 — `apply`: converge, and watch the ordering

`apply` re-runs the plan and then executes it, creating resources **in dependency
order**.

```bash
tofu apply -auto-approve
cat build/manifest.txt build/summary.txt
```

**Task:** In what order were the three resources created, and does that match the
graph you drew in Step 1?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
...
Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + release_name = (known after apply)
random_pet.release: Creating...
random_pet.release: Creation complete after 0s [id=firm-jackal]
local_file.manifest: Creating...
local_file.manifest: Creation complete after 0s [id=48211727af90c929fe3283609f0142c7af9ec0d8]
local_file.summary: Creating...
local_file.summary: Creation complete after 0s [id=1df579aafb092d49365dbaf1ec01c25f54dbc5dd]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

release_name = "firm-jackal"

$ cat build/manifest.txt build/summary.txt
release = firm-jackal
Deployed release = firm-jackal via the core workflow.
```

Creation order is **`random_pet.release` → `local_file.manifest` →
`local_file.summary`** — exactly the graph from Step 1. OpenTofu created the pet
first because the manifest references it, then the manifest before the summary.
The generated pet name (`firm-jackal` here — **yours will differ**) flowed through
every reference: into the manifest, into the summary, and out through the
`release_name` output.
</details>

---

## Step 5 — Idempotency: apply again, change nothing

The defining property of declarative IaC: re-running an unchanged config does
**nothing**.

```bash
tofu apply -auto-approve
```

**Task:** What does the **second** apply do, and why is that the whole point?

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
random_pet.release: Refreshing state... [id=firm-jackal]
local_file.manifest: Refreshing state... [id=48211727af90c929fe3283609f0142c7af9ec0d8]
local_file.summary: Refreshing state... [id=1df579aafb092d49365dbaf1ec01c25f54dbc5dd]

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

## Step 6 — Break → fix: a dependency cycle

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

## Step 7 — `destroy`: tear it down in reverse

`destroy` is the last command in the lifecycle: it removes everything in state,
in **reverse** dependency order.

```bash
rm -f broken.tf
tofu destroy -auto-approve
```

**Task:** What does the `-` symbol mean, and why is the destroy order the reverse
of the create order?

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
  # random_pet.release will be destroyed
  - resource "random_pet" "release" {
      - id        = "firm-jackal" -> null
      ...
    }

Plan: 0 to add, 0 to change, 3 to destroy.
...
local_file.summary: Destroying... [id=1df579aafb092d49365dbaf1ec01c25f54dbc5dd]
local_file.summary: Destruction complete after 0s
local_file.manifest: Destroying... [id=48211727af90c929fe3283609f0142c7af9ec0d8]
local_file.manifest: Destruction complete after 0s
random_pet.release: Destroying... [id=firm-jackal]
random_pet.release: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

- **`- destroy`** — each resource is being removed (attributes shown going
  `-> null`).
- Destruction order is **`summary` → `manifest` → `release`** — the **reverse** of
  create order. OpenTofu tears down dependents before their dependencies, so it
  never deletes something another resource still needs. The graph orders both
  directions for you. (If you removed `broken.tf` before this step, the plan is
  `3 to destroy`; if `ping`/`pong` were still applied it would be more.)

</details>

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

<details><summary>Expected output</summary>

```console
$ tofu destroy -auto-approve
local_file.summary: Destroying... [id=1df579aafb092d49365dbaf1ec01c25f54dbc5dd]
local_file.summary: Destruction complete after 0s
local_file.manifest: Destroying... [id=48211727af90c929fe3283609f0142c7af9ec0d8]
local_file.manifest: Destruction complete after 0s
random_pet.release: Destroying... [id=firm-jackal]
random_pet.release: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.
```

The generated state, `.terraform`, `build/`, and the scratch `broken.tf` are all
gitignored or removed; the panic reset leaves the tracked `main.tf` exactly as CI
verified it.
</details>

## Stretch (optional)

- Change `random_pet`'s `length` from `2` to `3`, run `tofu plan`, and read how
  OpenTofu proposes `-/+ destroy and then create replacement` with `~ … # forces
  replacement` — and how that **cascades** through the manifest and summary that
  reference it. That's the `~` symbol and the graph, together.

  <details><summary>Solution / expected output (the <code>~</code> and <code>-/+</code> symbols, verbatim)</summary>

  Apply first (so there's state to change), edit `length = 2` to `length = 3`,
  then `tofu plan`:

  ```console
  $ tofu plan
  random_pet.release: Refreshing state... [id=firm-jackal]
  ...
  OpenTofu used the selected providers to generate the following execution
  plan. Resource actions are indicated with the following symbols:
  -/+ destroy and then create replacement

  OpenTofu will perform the following actions:

    # local_file.manifest must be replaced
  -/+ resource "local_file" "manifest" {
        ~ content              = <<-EOT # forces replacement
              release = firm-jackal
          EOT -> (known after apply) # forces replacement
        ~ content_sha256       = "370a9f60...b004b9377ba3e1" -> (known after apply)
        ~ id                   = "48211727...af9ec0d8" -> (known after apply)
          # (3 unchanged attributes hidden)
      }

    # random_pet.release must be replaced
  -/+ resource "random_pet" "release" {
        ~ id        = "firm-jackal" -> (known after apply)
        ~ length    = 2 -> 3 # forces replacement
          # (1 unchanged attribute hidden)
      }

  Plan: 3 to add, 0 to change, 3 to destroy.
  ```

  Changing `length` **forces replacement** of `random_pet.release` (marked
  `~ length = 2 -> 3 # forces replacement`). Because the manifest and summary
  reference the pet's `id`, the replacement **cascades**: all three become `-/+`
  (destroy-then-create), and every referencing attribute shows `~ … ->
  (known after apply)`. This is the `~` symbol, the `-/+` compound action, and the
  dependency graph — all in one plan. (Hashes/ids are from one real run and will
  differ; restore `length = 2` afterwards.)

  </details>
- Run `tofu apply` with `-out=tfplan` to save the plan, then `tofu apply tfplan`
  to apply exactly that saved plan — the safe two-step review flow.
- Run `tofu graph` and paste the output into a Graphviz viewer to *see* the
  dependency DAG you drew by hand in Step 1.
