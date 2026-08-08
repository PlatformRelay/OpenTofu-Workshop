# Lab 27 — Map Terragrunt onto Terramate (S27) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

### Step 1 — Walk the Terragrunt tree

From the repository root, list the fixture and read each file:

```bash
find labs/day-3/27-terragrunt-comparison/terragrunt-style -type f | sort
cat labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
cat labs/day-3/27-terragrunt-comparison/terragrunt-style/live/network/terragrunt.hcl
cat labs/day-3/27-terragrunt-comparison/terragrunt-style/live/app/terragrunt.hcl
```

---

<details><summary>Solution / expected observation</summary>

```console
$ find labs/day-3/27-terragrunt-comparison/terragrunt-style -type f | sort
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

### Step 2 — Map three concepts onto Terramate

Gather the Terramate-side evidence:

```bash
grep -n "stack" labs/day-3/21-stacks/stacks/network/stack.tm.hcl
grep -n "generate_hcl" labs/day-3/22-codegen/backend.tm.hcl
grep -n "after" labs/day-3/23-orchestration/stacks/app/stack.tm.hcl
```

---

<details><summary>Solution / the completed mapping</summary>

| Terragrunt concept | Terramate equivalent |
| --- | --- |
| Unit — directory with `terragrunt.hcl` | **Stack** — directory with `stack.tm.hcl` (`labs/day-3/21-stacks/stacks/network/stack.tm.hcl`, the `stack {}` block). No block → the directory silently vanishes from `terramate list` (the S21 break). |
| `remote_state` / `generate` — boilerplate written **at run time** | **`generate_hcl`** + `globals` — `labs/day-3/22-codegen/backend.tm.hcl` emits `_backend.tf` **before commit**; `terramate generate` output is reviewed in the PR and drift-checked (S22's detailed exit code `2`). |
| `dependency` + `run-all` — ordering across units | **`after` / `before`** edges — `labs/day-3/23-orchestration/stacks/app/stack.tm.hcl` (`after = ["tag:networking"]`) orders `terramate run`; Git-based `--changed` (S24) narrows the set. |

One mapping is **deliberately imperfect**: Terragrunt's `dependency` block also
**wires outputs into inputs** (`dependency.network.outputs.network_name`).
Terramate's `after` only orders execution — data still flows between stacks
via normal OpenTofu means (remote state reads, data sources). If your fleet
leans hard on cross-unit output wiring, that is a real axis in the decision
table, not a rounding error.

</details>

---

### Step 3 — Break → fix: "Terragrunt hosts my state"

Find the planted claim and the evidence against it:

```bash
grep -n -A 2 "PLANTED CLAIM" labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
grep -n "backend" labs/day-3/27-terragrunt-comparison/terragrunt-style/root.hcl
```

---

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

## Expected state / output

- The fixture tree lists five tracked files; `find | sort` output matches the
  Step 1 spoiler exactly — nothing is generated, applied, or downloaded.
- The completed mapping table names a Terramate file for each of the three
  Terragrunt concepts: `stack.tm.hcl` (unit ↔ stack), `backend.tm.hcl`
  (`generate_hcl` ↔ `remote_state`/`generate`), and the `after` edge in
  `stacks/app/stack.tm.hcl` (`dependency`/`run-all` ↔ ordering).
- `grep -n "backend"` on `root.hcl` prints the three lines above — a `local`
  backend and a generated `backend.tf` path, and **no** hosted-state endpoint.
- After cleanup, `git status --short -- labs/day-3/27-terragrunt-comparison/`
  prints nothing and the `PLANTED CLAIM` comment is present again.

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

Both tools orchestrate **around** the engine, so every mapping lands on a file
that configures `tofu` rather than replacing it. The unit↔stack pair works
because each tool needs a marker file to discover work: Terragrunt finds
`terragrunt.hcl`, Terramate finds `stack {}` — which is why a directory without
the marker silently drops out of discovery in both worlds. The generation pair
differs in *when*, not *whether*: Terragrunt writes backend/provider files at
run time as it wraps each invocation, while Terramate generates them before
commit, so the emitted boilerplate is reviewable and drift-checkable in CI.
Ordering maps `dependency`/`run-all` onto `after`/`before` edges because both
must serialize roots the engine treats as independent.

The break→fix holds because `remote_state` *configures* a backend rather than
providing one: the state file lives wherever the generated `backend.tf` points,
so locking and encryption remain OpenTofu features, and RBAC/policy/audit
require the separate TACO platform layer from S11. Treating either CLI as a
state host therefore confuses three layers — engine, orchestrator, platform —
that this lab keeps deliberately distinct.

## Troubleshooting and recovery

Restore the tracked fixture if you edited the claim (the planted defect must
stay for the next cohort), and re-check that the tree is clean:

```bash
git restore -- labs/day-3/27-terragrunt-comparison/
git status --short -- labs/day-3/27-terragrunt-comparison/
```

To recover from a dead-end analysis, discard scratch notes and re-read the
fixture files from the participant lab — no infrastructure reset is required,
because this lab never runs `tofu`, Terragrunt, or Docker.

## Stretch solution

### Commands / manifest

Prove the "plain `tofu`" half of the comparison with Terramate on `PATH`
(S20 setup):

```bash
cd labs/day-3/23-orchestration
terramate list --run-order
cd ../../..
```

For the decision record, write one paragraph naming the dominant axis
(existing estate, reviewed codegen, selection model, CLI surface), the tool
that wins on it, and the trade-off accepted.

### Expected state / output

```console
$ terramate list --run-order
stacks/network
stacks/app
```

`network` prints before `app` — the `after = ["tag:networking"]` edge orders
the run, and the command Terramate would execute after `--` remains unmodified
`tofu`. A defensible decision record names one dominant axis and one accepted
trade-off (e.g. "reviewed codegen wins; we accept migrating existing
`terragrunt.hcl` units").

### Explanation

The stretch works because `terramate list --run-order` resolves the same
`after` edges that `terramate run` uses, so the printed order proves
orchestration happens **outside** the engine while the wrapped command stays
plain `tofu` — the wrapper-vs-runner split from the decision table. The
decision-record paragraph matters more than the tool name because the axes
trade off against each other; naming the accepted cost is what makes the
choice defensible.
