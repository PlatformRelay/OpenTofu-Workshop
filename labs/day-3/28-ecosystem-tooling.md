# Lab 28 — Run the everyday tooling belt (S28)

| | |
| --- | --- |
| **Section** | S28 — Ecosystem tooling *(optional appendix: version pins, module docs, commit hooks)* |
| **Environment** | `mock ✓ (no docker)` — local CLIs against tracked files. **No cloud, no Docker, no `tofu apply`.** The first `pre-commit run` fetches the hook repositories once (network). |
| **Estimated time** | 20 min |

## Objective

Survey the three everyday ecosystem tools this repository already uses —
**tenv** for engine version pinning, **terraform-docs** for module README
generation, and **pre-commit** for local IaC gates — by reading the
**checked-in configs** (not a parallel demo stack), then run the pre-commit
track for real: dirty a tracked fixture on purpose, let the repository's own
hooks catch **and fix** it, and prove the tree comes back byte-identical.

The tenv and terraform-docs steps are **read-only** — neither tool needs to be
installed. Only the pre-commit track executes a tool, and a missing tool fails
into install guidance, never into a blocked Day 3.

## Prerequisites

- OpenTofu ≥ 1.8 (`tofu version`).
- **pre-commit ≥ 3.5** for Steps 3–5 (`pre-commit --version`). Missing? Step 3
  gives install guidance and a facilitator demo-only path.
- A terminal at the repository root. `tenv` and `terraform-docs` are **not**
  required (read-only survey here; optional stretch if installed).

## Files used

- [`versions.env`](../../versions.env) — the repository's toolchain pin file
  (single source of truth).
- [`modules/naming/.terraform-docs.yml`](../../modules/naming/.terraform-docs.yml)
  — the checked-in terraform-docs config (its twin lives in `modules/labels/`).
- [`.pre-commit-config.yaml`](../../.pre-commit-config.yaml) — the repository's
  real hook wiring.
- [`labs/day-3/28-ecosystem-tooling/main.tf`](./28-ecosystem-tooling/main.tf) — the
  small tracked fixture you will dirty and let the hooks repair.

The fixture (tracked, canonically formatted — you break it later on purpose):

<!-- source: labs/day-3/28-ecosystem-tooling/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"
}

variable "docs_owner" {
  description = "Team that owns generated module documentation."
  type        = string
  default     = "platform"
}

output "gate_summary" {
  description = "One-line summary of the local quality gates."
  value       = "fmt, docs, and hooks guard ${var.docs_owner} commits"
}
```

---

## Step 1 — Read the version pin (tenv survey, read-only)

Every reproducibility-critical tool version in this workshop lives in one file.
Find the engine pin:

```bash
grep -n "TOFU_VERSION" versions.env
```

**Task:** Where is OpenTofu pinned, and how would a version manager like tenv
consume that pin on a laptop that juggles several OpenTofu projects?

<details><summary>Solution / expected observation</summary>

```console
$ grep -n "TOFU_VERSION" versions.env
13:TOFU_VERSION=1.10.3
```

`versions.env` is the pin's single source of truth — Taskfile, docker compose,
CI, and the bootstrap all read it, and `scripts/verify.sh` fails on skew.

**tenv** is the version-manager half of the story: the actively maintained
successor to `tfenv`/`tofuenv`, one binary that manages **OpenTofu, Terraform,
Terragrunt, Terramate, and Atmos**. With it installed you would mirror the repo pin
locally:

```bash
tenv tofu install 1.10.3
tenv tofu use 1.10.3
tofu version
```

tenv resolves versions from its arguments or from a version file such as
`.opentofu-version`, so each project can pin its own engine. This workshop
deliberately does **not** make tenv part of `task setup` — any `tofu ≥ 1.8`
works here. tenv is the take-it-to-work tool for estates where projects pin
different engine versions.

No tenv installed? Nothing to do — this step is read-only. To try it later:
`brew install tenv`, or grab a release from the `tofuutils/tenv` GitHub page.

</details>

---

## Step 2 — Read the module-docs contract (terraform-docs survey, read-only)

The `modules/naming` and `modules/labels` READMEs contain a machine-owned
region. Find the config that owns it and the markers that bound it:

```bash
cat modules/naming/.terraform-docs.yml
grep -n "BEGIN_TF_DOCS\|END_TF_DOCS" modules/naming/README.md
```

**Task:** Which README lines does terraform-docs own, what command regenerates
them, and what stops the tool from overwriting the hand-written prose above?

<details><summary>Solution / expected observation</summary>

```console
$ grep -n "BEGIN_TF_DOCS\|END_TF_DOCS" modules/naming/README.md
85:<!-- BEGIN_TF_DOCS -->
109:<!-- END_TF_DOCS -->
```

The config declares `formatter: markdown table`, shows only `inputs` and
`outputs`, and — the key part — uses **inject mode**: `output.file: README.md`
with a template bounded by the `BEGIN_TF_DOCS` / `END_TF_DOCS` markers. The
tool owns exactly the lines between the markers; everything above them (usage
examples, design rationale) is hand-written and untouched. Regeneration is one
command from the module directory:

```bash
cd modules/naming
terraform-docs -c .terraform-docs.yml .
cd ../..
```

The same contract is wired into the commit boundary: the repository's
`.pre-commit-config.yaml` runs a `terraform_docs` hook, so a changed variable
without regenerated docs fails locally before CI ever sees it. Actually
running the regeneration (and reading the diff it produces) is the Stretch —
the survey needs only the contract.

</details>

---

## Step 3 — Preflight the hook runner

The rest of the lab executes the repository's own pre-commit gates. Check the
runner and point the Terraform-ecosystem hooks at the OpenTofu binary:

```bash
pre-commit --version
export PCT_TFPATH="$(command -v tofu)"
```

**Task:** Confirm a version ≥ 3.5 prints, and explain what `PCT_TFPATH` does
(the header comment of `.pre-commit-config.yaml` is the authoritative answer).

> **Facilitator tip — demo-only path.** If the room lacks `pre-commit`
> (locked-down laptops, or no network for the one-time hook fetch), run
> Steps 4–5 once on the projector and have learners follow along in
> `.pre-commit-config.yaml` instead. This appendix must never block Day 3.

<details><summary>Solution / expected observation</summary>

```console
$ pre-commit --version
pre-commit 4.6.1
```

(Your exact version will differ; ≥ 3.5 is what matters.)

Any version ≥ 3.5 satisfies the config's `minimum_pre_commit_version`. If the
command is missing, install it and rerun:

```bash
pipx install pre-commit   # the repo's documented path
# or: brew install pre-commit
```

`PCT_TFPATH` is the `pre-commit-terraform` suite's environment variable for
selecting the binary its hooks shell out to. The hooks support both Terraform
and OpenTofu; `entry`/`language` of a remote hook are not user-overridable, so
exporting `PCT_TFPATH="$(command -v tofu)"` is the supported switch that makes
`terraform_fmt` run `tofu fmt` — the same wiring S13 showed on its automation
slide.

</details>

---

## Step 4 — Break → fix: the formatting hook

Dirty the tracked fixture deliberately (one mis-indented, mis-aligned line),
then let the repository's `terraform_fmt` hook catch it:

```bash
perl -pi -e 's/^  type        = string/ type = string/' labs/day-3/28-ecosystem-tooling/main.tf
pre-commit run terraform_fmt --files labs/day-3/28-ecosystem-tooling/main.tf
```

**Task:** Read the hook result. Did it only *detect* the problem — and what
does the working tree look like afterwards?

<details><summary>Solution / expected failure (and auto-fix)</summary>

On the first ever run, pre-commit prints a few `[INFO] Initializing
environment …` lines while it fetches the hook repositories. Then:

```console
tofu fmt.................................................................Failed
- hook id: terraform_fmt
- files were modified by this hook
main.tf
```

The hook **failed the run and fixed the file in the same pass** — `tofu fmt`
rewrites in place, unlike the read-only `tofu fmt -check` from S13. Because
canonical formatting is deterministic, the repaired file is byte-identical to
the tracked version:

```bash
git status --short -- labs/day-3/28-ecosystem-tooling/
pre-commit run terraform_fmt --files labs/day-3/28-ecosystem-tooling/main.tf
```

```console
tofu fmt.................................................................Passed
```

`git status` prints nothing for the fixture, and the rerun is green — the
fail-then-fix loop is the hook's contract: it never lets a commit through
dirty, and the second attempt succeeds.

</details>

---

## Step 5 — Break → fix: the hygiene hook

Formatting is only one gate in the checked-in suite. Plant trailing
whitespace — invisible in most editors — and run the matching hygiene hook:

```bash
perl -pi -e 's/\{$/\{  / if $. == 1' labs/day-3/28-ecosystem-tooling/main.tf
pre-commit run trailing-whitespace --files labs/day-3/28-ecosystem-tooling/main.tf
```

**Task:** Which hook repository does this gate come from, and why does a
whitespace gate matter for IaC repositories at all?

<details><summary>Solution / expected failure (and auto-fix)</summary>

```console
trim trailing whitespace.................................................Failed
- hook id: trailing-whitespace
- exit code: 1
- files were modified by this hook
Fixing labs/day-3/28-ecosystem-tooling/main.tf
```

This hook comes from the generic `pre-commit/pre-commit-hooks` repository —
the third block of `.pre-commit-config.yaml`, next to `end-of-file-fixer`,
`check-merge-conflict`, `check-yaml`, and `mixed-line-ending`. Whitespace
noise creates phantom diffs in review and can even disarm byte-exact checks
(this repo's slide↔lab drift gate compares bytes). The rerun is green and the
tree is clean again:

```bash
pre-commit run trailing-whitespace --files labs/day-3/28-ecosystem-tooling/main.tf
git status --short -- labs/day-3/28-ecosystem-tooling/
```

```console
trim trailing whitespace.................................................Passed
```

One suite, three families of gates — OpenTofu hooks (`terraform_fmt`,
`terraform_tflint`, `terraform_docs`), secret scanning (`gitleaks`), and
generic hygiene — all in a single tracked file every contributor shares.

</details>

---

## Expected observations

- `versions.env` pins `TOFU_VERSION=1.10.3` once; tenv is how a laptop mirrors
  such a pin per project — and it stays **optional** in this workshop.
- terraform-docs owns exactly the marker-bounded README region; the checked-in
  `.terraform-docs.yml` (inject mode) is the contract, and a pre-commit hook
  enforces regeneration.
- `pre-commit run <hook-id> --files <path>` scopes the repository's real gates
  to one file; `PCT_TFPATH` points the Terraform-ecosystem hooks at `tofu`.
- Fixing hooks **fail the run and repair the file in the same pass** — the
  rerun proves the fix, and deterministic formatting restores the tracked
  bytes exactly.
- A missing tool degrades to install guidance or a facilitator demo — the
  appendix never blocks Day 3.

## Cleanup / panic reset

The hooks already restored the fixture; this is the belt-and-braces reset.
Nothing else was created — no state, no processes, no containers:

```bash
git restore -- labs/day-3/28-ecosystem-tooling/
git status --short -- labs/day-3/28-ecosystem-tooling/
```

<details><summary>Solution / expected cleanup</summary>

`git status --short -- labs/day-3/28-ecosystem-tooling/` prints nothing. The
fixture is back to its tracked, canonically formatted form.

</details>

## Stretch (optional)

- **Regenerate the module docs for real** (needs `terraform-docs` on `PATH`;
  install: `brew install terraform-docs`):

  ```bash
  cd modules/naming
  terraform-docs -c .terraform-docs.yml .
  git diff --stat -- README.md
  git restore -- README.md
  cd ../..
  ```

  Expect a real diff: the tracked table was hand-tidied, and the tool emits
  its own normalized form (escaped underscores, expanded default values,
  its own sort order). The markers bound the blast radius — the prose above
  `BEGIN_TF_DOCS` never changes. Restore afterwards; deliberately syncing the
  README to raw tool output is a maintainer decision, not a lab side effect.

- **Mirror the engine pin with tenv** (needs `tenv`; install:
  `brew install tenv`):

  ```bash
  tenv tofu install 1.10.3
  tenv tofu list
  ```

  The pinned version appears in the installed list; `tenv tofu uninstall
  1.10.3` removes it again if you were only experimenting.
