# Lab 27 — Map Terragrunt onto Terramate (S27)

| | |
| --- | --- |
| **Section** | S27 — Terragrunt vs Terramate *(optional appendix: choose or defend an orchestrator)* |
| **Environment** | `mock ✓ (paper + fixture · no docker)` — read-only inspection. **No Terragrunt install, no cloud, no `tofu apply`.** |
| **Estimated time** | 20 min |

## Objective

Terragrunt and Terramate solve the same "many roots" problem with different
philosophies. In this lab you **read** a small, illustrative `terragrunt.hcl`
tree (never executed — the workshop does not install Terragrunt), map **three
Terragrunt concepts onto the Terramate equivalents** you used in S21–S23, and
**break→fix** a planted misconception: that Terragrunt's `remote_state` makes
it a state host / TACO platform. It does not — and proving that from the
config is the point.

Everything runs with `cat` and `grep` against tracked files. The Terramate
side of every mapping is the workdirs you already used:
[`labs/day-3/21-stacks/`](./21-stacks/), [`labs/day-3/22-codegen/`](./22-codegen/),
and [`labs/day-3/23-orchestration/`](./23-orchestration/).

## Prerequisites

- Day-3 core sections S20–S23 (stacks, codegen, orchestration) — conceptually.
- A terminal at the repository root. No Terragrunt, no Terramate, no Docker,
  no cloud account required. (`terramate` is only touched in the optional
  stretch.)

## Files used

- [`labs/day-3/27-terragrunt-comparison/terragrunt-style/`](./27-terragrunt-comparison/terragrunt-style/)
  — an illustrative Terragrunt monorepo: a root config plus two units
  (`live/network`, `live/app`) that consume plain OpenTofu configs under
  `units/`. **Fixture only — nothing in it is ever executed.**
- [`labs/day-3/22-codegen/`](./22-codegen/) and
  [`labs/day-3/23-orchestration/`](./23-orchestration/) — the Terramate side
  of the mapping (read-only here).

The root Terragrunt config (tracked, with the planted claim):

<!-- source: labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl -->
```hcl
# Root Terragrunt configuration — illustrative fixture only (Lab 27).
# The workshop does not install or run Terragrunt; you only READ this tree
# and map its concepts onto the Terramate workdirs from S21-S23.

# PLANTED CLAIM — wrong on purpose (Lab 27 break → fix):
# "remote_state means Terragrunt itself stores this state and serves it
# to the team, like a TACO platform's hosted backend."

remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    path = "terraform.tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "local" {}
  EOF
}
```

The app unit, with dependency wiring (tracked):

<!-- source: labs/day-3/27-terragrunt-comparison/terragrunt-style/live/app/terragrunt.hcl -->
```hcl
# App unit — illustrative fixture only (Lab 27). Never executed.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../units/app"
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_name = "mock-network"
  }
}

inputs = {
  network_name = dependency.network.outputs.network_name
}
```

---

## Step 1 — Walk the Terragrunt tree

From the repository root, list the fixture and read each file:

```bash
find labs/day-3/27-terragrunt-comparison/terragrunt-style -type f ! -name '.terraform.lock.hcl' -not -path '*/.terraform/*' | sort
cat labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
cat labs/day-3/27-terragrunt-comparison/terragrunt-style/live/network/terragrunt.hcl
cat labs/day-3/27-terragrunt-comparison/terragrunt-style/live/app/terragrunt.hcl
```

**Task:** What is the *unit of work* in this tree, and how does a unit find
its shared configuration?

<details><summary>Solution / expected observation</summary>

```console
$ find labs/day-3/27-terragrunt-comparison/terragrunt-style -type f ! -name '.terraform.lock.hcl' -not -path '*/.terraform/*' | sort
labs/day-3/27-terragrunt-comparison/terragrunt-style/live/app/terragrunt.hcl
labs/day-3/27-terragrunt-comparison/terragrunt-style/live/network/terragrunt.hcl
labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
labs/day-3/27-terragrunt-comparison/terragrunt-style/units/app/main.tf
labs/day-3/27-terragrunt-comparison/terragrunt-style/units/network/main.tf
```

The unit of work is **a directory containing `terragrunt.hcl`** (`live/network`,
`live/app`). Each unit pulls shared settings with
`include "root" { path = find_in_parent_folders("root.hcl") }` — inheritance by
**file lookup up the tree**. The actual OpenTofu code lives elsewhere
(`units/…`) and is referenced via `terraform { source = … }`, so a unit is
configuration *about* a root, not the root itself.

</details>

---

## Step 2 — Map three concepts onto Terramate

Fill in the right-hand column, quoting the Terramate file that proves each
equivalent. Gather the evidence with:

```bash
grep -n "stack" labs/day-3/21-stacks/stacks/network/stack.tm.hcl
grep -n "generate_hcl" labs/day-3/22-codegen/backend.tm.hcl
grep -n "after" labs/day-3/23-orchestration/stacks/app/stack.tm.hcl
```

| Terragrunt concept | Terramate equivalent (name file + block) |
| --- | --- |
| Unit — directory with `terragrunt.hcl` | ? |
| `remote_state` / `generate` — run-time boilerplate | ? |
| `dependency` + `run --all` — ordering across units | ? |

<details><summary>Solution / the completed mapping</summary>

| Terragrunt concept | Terramate equivalent |
| --- | --- |
| Unit — directory with `terragrunt.hcl` | **Stack** — directory with `stack.tm.hcl` (`labs/day-3/21-stacks/stacks/network/stack.tm.hcl`, the `stack {}` block). No block → the directory silently vanishes from `terramate list` (the S21 break). |
| `remote_state` / `generate` — boilerplate written **at run time** | **`generate_hcl`** + `globals` — `labs/day-3/22-codegen/backend.tm.hcl` emits `_backend.tf` **before commit**; `terramate generate` output is reviewed in the PR and drift-checked (S22's detailed exit code `2`). |
| `dependency` + `run --all` — ordering across units | **`after` / `before`** edges — `labs/day-3/23-orchestration/stacks/app/stack.tm.hcl` (`after = ["tag:networking"]`) orders `terramate run`; Git-based `--changed` (S24) narrows the set. |

One mapping is **deliberately imperfect**: Terragrunt's `dependency` block also
**wires outputs into inputs** (`dependency.network.outputs.network_name`).
Terramate's `after` only orders execution — data still flows between stacks
via normal OpenTofu means (remote state reads, data sources). If your fleet
leans hard on cross-unit output wiring, that is a real axis in the decision
table, not a rounding error.

</details>

---

## Step 3 — Break → fix: "Terragrunt hosts my state"

The fixture plants a wrong claim. Find it:

```bash
grep -n -A 2 "PLANTED CLAIM" labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
```

**Break:** take the claim at face value — *"`remote_state` means Terragrunt
stores this state and serves it to the team, like a TACO platform's hosted
backend."* If that were true, where would `terraform.tfstate` live, and what
would enforce RBAC on it?

**Fix:** disprove it from the config itself, then correct the comment.

```bash
grep -n "backend" labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
```

Edit the two quoted claim lines in
`labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl` to state what
`remote_state` actually does (see the spoiler), then compare with the spoiler
and **restore the tracked fixture** (the planted claim must stay for the next
cohort — Cleanup below).

<details><summary>Solution / the corrected claim</summary>

The config disproves the claim on its own:

```console
$ grep -n "backend" labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
7:# to the team, like a TACO platform's hosted backend."
10:  backend = "local"
13:    path      = "backend.tf"
```

`remote_state` only **writes a `backend.tf`** into each unit at run time —
here a `local` backend, so state would land in a plain `terraform.tfstate`
on disk, hosted by **nobody**. Point the same block at `s3` and the state
lives in **your** bucket. Either way Terragrunt never stores, serves, or
guards state — exactly like Terramate's `generate_hcl "_backend.tf"` in
`labs/day-3/22-codegen/backend.tm.hcl`, which emits the same kind of file
before commit. Locking and encryption stay OpenTofu's job (the S20
non-negotiable), and RBAC / policy / audit belong to the **TACO platform
layer** from S11 — a third layer, not either CLI.

A corrected comment reads:

```text
# CORRECTED: remote_state only GENERATES backend configuration for each
# unit. The state itself lives wherever that backend points (here: a local
# terraform.tfstate). Terragrunt is an orchestrator, not a TACO/state host.
```

</details>

---

## Expected observations

- Both trees name the same unit of work — a **directory** (`terragrunt.hcl`
  unit ↔ `stack.tm.hcl` stack) — around unchanged `tofu` roots.
- Boilerplate generation differs in **when**, not whether: Terragrunt writes
  at run time; Terramate generates before commit for PR review + drift check.
- Ordering differs in **selection**: `dependency`/`run --all` subtree walks vs
  `after` edges + Git `--changed`.
- `remote_state` **configures** a backend; it does not host one. Neither tool
  manages state; neither is a TACO.
- **This workshop's path is Terramate** (S20–S26); Terragrunt stays a
  defensible choice for estates that already speak it.

## Cleanup / panic reset

Restore the fixture (the planted claim must stay tracked for the next
cohort). Nothing else was created — no state, no processes, no containers:

```bash
git restore -- labs/day-3/27-terragrunt-comparison/
git status --short -- labs/day-3/27-terragrunt-comparison/
```

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-3/27-terragrunt-comparison/` prints nothing.
The `PLANTED CLAIM` comment is back in `terragrunt-style/root.hcl`.

</details>

## Stretch (optional)

- **Prove the "plain `tofu`" half of the comparison.** With Terramate on
  `PATH` (S20 setup), run the S23 fleet and note the commands are unmodified
  `tofu` after the `--`:

  ```bash
  cd labs/day-3/23-orchestration
  terramate list --run-order
  cd ../../..
  ```

  Terragrunt's equivalent (`terragrunt run --all plan`, formerly spelled
  `terragrunt run-all plan`) rewrites the command surface itself — the
  wrapper-vs-runner split from the decision table.
- **Write the one-paragraph decision record** for *your* real estate: which
  axis from the S27 decision table dominates (existing estate, reviewed
  codegen, selection model, CLI surface), which tool wins, and the trade-off
  you accept. The paragraph — not the tool name — is the deliverable.
