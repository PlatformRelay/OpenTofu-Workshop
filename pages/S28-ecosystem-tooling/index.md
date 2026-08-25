---
layout: section-cover
image: /covers/placeholder-section.svg
aiGenerated: false
day: Day 3
section: '28'
tier: optional
---

# Ecosystem tooling

## tenv, terraform-docs, pre-commit — an optional appendix

Around every OpenTofu estate sits an everyday tooling belt: a **version
manager**, a **docs generator**, and **commit-time gates**. This short survey
shows all three through the configs **this repository already ships** — so you
can adopt them at work without three new workshop days.

<!--
Say: Frame this as the last appendix, not new core time. The workshop taught
the engine, the tests, and the scaling story; around all of that sits a small
belt of everyday tools most IaC teams run: tenv to pin engine versions,
terraform-docs to keep module READMEs honest, and pre-commit to gate commits
locally. The trick of this section is that there is nothing new to build — the
repository already ships a version pin file, terraform-docs configs, and a
pre-commit suite, so we survey the real thing. Twenty minutes of slides, one
hands-on lab. (~1 min)
Then: "Name the three everyday frictions these tools remove."
-->

---
layout: statement
kicker: 'The problem frame'
---

**Three everyday frictions, none engine-shaped.** Which `tofu` binary is this
project pinned to? Are the module READMEs still true? Did that commit just
push unformatted HCL at CI?

Version managers, docs generators, and hook runners answer these **around**
the engine — none replaces `tofu`, and none needs a workshop day of its own.

<!--
Say: None of these frictions is about writing HCL — they are about operating
an estate day to day. Friction one: a laptop juggling five projects on three
engine versions. Friction two: module documentation that drifted from the
variables the module actually has. Friction three: commits that reach CI only
to bounce on formatting a local hook would have caught in a second. Each tool
in this section removes exactly one friction, sits outside the engine, and is
adoptable independently — that is why this is a survey, not a new day. Scope
fence for the room: this is not the orchestrator story — Terramate had S20 to
S25 and the Terragrunt comparison was S27 — and it is not the platform story
from S11. It is the small stuff you touch every single day. (~2 min)
Then: "Start with the version pin."
-->

---
layout: comparison
leftHeading: The pin (this repo)
leftBadge: versions.env
rightHeading: The manager (your laptop)
rightBadge: tenv
---

<span class="kw-kicker">Engine versions · pin once, mirror everywhere</span>

```bash
$ grep -n "TOFU_VERSION" versions.env
13:TOFU_VERSION=1.10.3
```

- **One file pins the toolchain** — Taskfile, docker compose, CI, and
  bootstrap all consume it.
- `scripts/verify.sh` **fails on consumer skew** — the pin cannot silently
  drift.

::right::

```bash
tenv tofu install 1.10.3
tenv tofu use 1.10.3
tofu version   # ← the pinned engine
```

- **tenv** — successor to `tfenv`/`tofuenv`; one binary manages **OpenTofu,
  Terraform, Terragrunt, Terramate, Atmos**.
- Resolves versions per project (args, env, or an `.opentofu-version` file).
- **Not** part of `task setup` here — `tofu ≥ 1.8` runs most labs (Labs 06 and 10 need ≥ 1.9). Adopt
  it at work.

<!--
Say: Left side is what the repository already does: versions.env is the single
source of truth for every reproducibility-critical tool version, and the
verify script fails the build when any consumer drifts from it. Right side is
the laptop half of the same idea: tenv, the actively maintained successor to
tfenv and tofuenv, is one binary that manages OpenTofu, Terraform, Terragrunt, Terramate,
and Atmos, and resolves the wanted version per project — from arguments or a
version file like dot-opentofu-version. Be explicit about the boundary: this
workshop deliberately does not require tenv — any tofu one-point-eight or newer
runs most labs, and Labs 06 and 10 need one-point-nine — so the takeaway is a
pattern to carry to work, not a new setup step.
(~4 min)
Then: "Second friction — module docs that lie."
-->

---
layout: comparison
leftHeading: The contract
leftBadge: '.terraform-docs.yml'
rightHeading: The regeneration
rightBadge: inject mode
---

<span class="kw-kicker">Module docs · generated from the code they describe</span>

```yaml
# modules/naming/.terraform-docs.yml (excerpt)
formatter: markdown table
sections:
  show: [inputs, outputs]
output:
  file: README.md
  mode: inject
```

- Checked in **per module** — `modules/naming/` and `modules/labels/` each
  ship one.
- Tables are derived from `variables.tf` / `outputs.tf` — docs cannot drift
  from the contract.

::right::

```bash
cd modules/naming
terraform-docs -c .terraform-docs.yml .
```

- **Inject mode** owns only the region between `<!-- BEGIN_TF_DOCS -->` and
  `<!-- END_TF_DOCS -->` in the README.
- Hand-written prose above the markers is **never touched**.
- Also wired as the `terraform_docs` **pre-commit hook** — forgotten
  regeneration fails before CI.

<!--
Say: terraform-docs generates the inputs-and-outputs half of a module README
straight from the variables and outputs files, so the reference tables cannot
drift from the code. The config is checked in per module — both workshop
modules ship one — and the key setting is inject mode: the tool owns exactly
the region between the BEGIN and END markers, while the hand-written usage
examples and rationale above them stay human-owned. Regeneration is one
command from the module directory, and the same contract is enforced at the
commit boundary by the terraform-docs pre-commit hook, which is the perfect
segue. (~4 min)
Then: "Third friction — and the tool that ties the belt together."
-->

---
layout: comparison
leftHeading: The checked-in suite
leftBadge: '.pre-commit-config.yaml'
rightHeading: Running it OpenTofu-first
rightBadge: PCT_TFPATH
---

<span class="kw-kicker">Commit gates · the repo's real hook wiring</span>

```yaml
# .pre-commit-config.yaml (excerpt; names/args elided)
repos:
  - repo: …/antonbabenko/pre-commit-terraform
    rev: v1.99.0
    hooks: [terraform_fmt, terraform_tflint, terraform_docs]
  - repo: …/gitleaks/gitleaks
  - repo: …/pre-commit/pre-commit-hooks
```

Three gate families: **OpenTofu hooks · secret scan · generic hygiene.**

::right::

```bash
export PCT_TFPATH="$(command -v tofu)"
pre-commit run --all-files
```

- `PCT_TFPATH` points the `pre-commit-terraform` hooks at **`tofu`** — remote
  hooks' `entry` is not overridable, so the env var is the supported switch.
- Fixing hooks **fail the run and repair the file in the same pass** — the
  rerun goes green.
- S13/S19 showed this config as the fast feedback loop; S28 adds where it
  sits in the wider belt. S13 names **Gitleaks** as already running in the
  learner's own `pre-commit run --all-files`, flags that **`terraform-docs`**
  needs the binary on `PATH` first, and sends both here for the beat.

<!--
Say: The commit-time gate is the repository's own pre-commit config — the same
file S13 pointed at for the fast feedback loop and S19 placed against CI. It
wires three gate families: the antonbabenko pre-commit-terraform hooks running
tofu fmt, TFLint, and terraform-docs; gitleaks for secret scanning; and the
generic hygiene hooks like trailing-whitespace and end-of-file-fixer. Two
behaviours matter for the lab. First, PCT_TFPATH: the terraform-ecosystem
hooks serve both Terraform and OpenTofu, and since a remote hook's entry is
not user-overridable, exporting PCT_TFPATH pointing at tofu is the supported
OpenTofu-first switch. Second, the fixing-hook contract: a dirty file fails
the run and gets repaired in the same pass, so the rerun is green — fail then
fix, never silently dirty. (~5 min)
Then: "Prove that contract on a tracked fixture — the lab."
-->

---
layout: lab
lab: labs/day-3/28-ecosystem-tooling.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 28 — run the everyday tooling belt

Survey by reading, then gate for real: read the **version pin** and the
**docs contract**, then dirty this tracked fixture and let the repository's
own hooks catch **and fix** it:

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

No cloud, no Docker. Missing `pre-commit` → install guidance + a facilitator
demo-only path.

<!--
Say: Set up the lab. Steps one and two are read-only surveys — find the engine
pin in versions.env and the marker-bounded README region terraform-docs owns —
so they need no tools installed. Steps three to five are the hands-on track:
preflight pre-commit with install guidance if it is missing, export PCT_TFPATH,
then break this fixture twice on purpose — one mis-indented line for the
tofu-fmt hook, one line of trailing whitespace for the hygiene hook — and
watch each hook fail the run while fixing the file, with the rerun green and
git status clean. If the room has no pre-commit or no network for the one-time
hook fetch, run it once on the projector — the appendix never blocks Day 3.
(~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Ecosystem tooling — recap
story: 'A three-piece everyday belt around the engine — surveyed on this repo''s own configs.'
next: 'End of the superset — the Day-3 track closed with S26.'
---

- **tenv** pins the engine per project — the laptop mirror of
  `versions.env`'s `TOFU_VERSION=1.10.3`; successor to `tfenv`/`tofuenv`,
  optional here, valuable at work.
- **terraform-docs** generates module reference tables from the code —
  inject mode owns only the marker-bounded README region; config checked in
  per module.
- **pre-commit** runs the local gates — OpenTofu hooks, secret scan, hygiene
  in one tracked file; `PCT_TFPATH` keeps the suite OpenTofu-first.
- **Fixing hooks fail then repair** — the rerun proves the fix; deterministic
  `fmt` restores tracked bytes exactly.
- **Adopt independently** — each tool removes one friction; none needs a
  platform (S11), an orchestrator (S20–S27), or a new workshop day.

<!--
Say: Close the belt in one breath. tenv pins the engine per project and is the
laptop half of the versions.env pin — optional in this workshop, valuable in
any estate juggling engine versions. terraform-docs keeps module READMEs
truthful by generating the reference tables from the code, owning only the
marker-bounded region. pre-commit ties the belt together: the repository's one
tracked config runs the OpenTofu hooks, secret scanning, and hygiene, with
PCT_TFPATH keeping everything OpenTofu-first, and fixing hooks that fail the
run while repairing the file. The adoption message is the closer: each of the
three stands alone — pick the friction that hurts most at work and start
there. (~2 min)
Then: this appendix ends the superset deck — hand back to the Day-3 wrap.
-->
