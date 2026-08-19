# Syllabus — OpenTofu Practitioner Workshop

A hands-on, vendor-neutral OpenTofu workshop. Roughly **50% presentation, 50%
practice**. Labs run against LocalStack or `mock_provider` — no cloud account.

This page is the public section map. Facilitators should also read the
[facilitator runbook](facilitator-runbook.md). Architectural decisions live in
[docs/decisions/](https://github.com/PlatformRelay/OpenTofu-Workshop/tree/main/docs/decisions)
on GitHub.

## Spine: Author → Test → Scale

| Phase | Days (canonical cut) | What learners build |
| --- | --- | --- |
| **Author** | Day 1 | HCL, plan/apply, state + encryption, variables, validation, modules, naming/labels |
| **Test** | Day 2 | Testing pyramid, fmt/lint, scanners, `tofu test`, mocks, CI honesty |
| **Scale** | Day 3 | Terramate stacks, codegen, orchestration, change detection, capstone |

## The evolving project: `service-manifest`

Every hands-on stage grows **one** project — `service-manifest`: a rendered
service manifest file, plus the variables, guards, state, module, tests and
pipeline that accumulate around it. The name is the child module already in the
tree at `labs/day-1/07-modules/modules/service-manifest/`, which is its source
of truth; `svc-manifest` is informal shorthand for the same thing.

This is a different axis from **Author → Test → Scale** above: that is the
three-day arc, this is the single artefact carried along it.

This page is the **canonical** copy of the stage map and the continuity rule.
The [facilitator runbook](facilitator-runbook.md) repeats the table for delivery
use and `AGENT.md` repeats the rule for authoring — edit here first, then
propagate.

### Stage map

Stage numbers are the teaching sequence. Section IDs never change — nothing is
renumbered, so the Day-1 IDs are deliberately out of numeric order. Since the
Day-1 resequencing landed (US-C-RESEQ) the live delivery order **is** the stage
order: `S00 → S01 → S02 → S03 → S06 → S15 → S04 → S05 → S07 → S08`.

**Where each concept is introduced:** `resource` → stage 0 · `variable` →
stage 2 (block taxonomy; first appears as a feature switch at stage 0b; typed,
validated and sensitive at stage 4) · `output` → stage 2 (block taxonomy; first
appears in the stage-1 lab config) · `plan` → stage 0 (read line by line at
stage 3) · `apply` → stage 0 (full lifecycle at stage 3) · state → stage 6
(named at stage 0, motivated at stage 3) · modules → stage 8 · testing → stage 10
(`tofu test` with `mock_provider` first taught at stage 9) · CI → stage 14.

| Stage | Section | Workdir | Introduces |
| --- | --- | --- | --- |
| 0 | S00 · Welcome & setup | `labs/day-1/00-setup/` | **`resource`**, `init`, the first **`plan`** and **`apply`** |
| 0b | S00 · stretch | `labs/day-1/00-setup/` | the first cloud-shaped resource (S3 on LocalStack), gated by the first `variable` — a `bool` feature switch |
| 1 | S01 · Infrastructure as Code | `labs/day-1/01-iac-fork/` | declarative vs imperative — the lab config surfaces its first `output`, though the block type is taught at stage 2 |
| 2 | S02 · HCL & building blocks | `labs/day-1/02-hcl-blocks/` | the block taxonomy — **`variable`**, **`output`**, `locals`, `data`, references (`module` is only a forward reference to stage 8) |
| 3 | S03 · The core workflow | `labs/day-1/03-core-workflow/` | the four-command loop — **plan diffs**, the graph, `destroy`, and *why* state exists |
| 4 | S06 · Variables, validation & types | `labs/day-1/06-variables/` | **typed, validated and sensitive `variable`s** — the project's own inputs |
| 5 | S15 · Validation, preconditions & checks | `labs/day-1/15-conditions-checks/` | `precondition`, `postcondition`, `check` |
| 6 | S04 · State | `labs/day-1/04-state/` | **state**, drift, backends |
| 7 | S05 · State encryption | `labs/day-1/05-state-encryption/` | encrypted state and encrypted plan |
| 8 | S07 · Modules | `labs/day-1/07-modules/` | **`module`** — `./modules/service-manifest` consumed twice |
| 9 | S08 · Naming & labelling module | `examples/naming-labels-demo/` | one naming + labelling taxonomy — and the first `tofu test` run, with an aliased `mock_provider` |
| 10 | S12, S13 | `labs/day-2/12-testing-pyramid/`, `13-static-analysis/` | **testing as a discipline** — the pyramid, `fmt`, TFLint, pre-commit |
| 11 | S14 · Security & policy scanners | `labs/day-2/14-security-scanners/` | policy + security scanning (planted insecure fixture — deliberately *not* the learner's project) |
| 12 | S16, S17 | `labs/day-2/16-tofu-test/`, `17-mocking/` | `tofu test` in depth — apply vs plan runs, and mocking beyond stage 9's first taste |
| 13 | S18 · Integration, e2e & cost | `labs/day-2/18-terratest-cost/` | integration + cost (optional tier) |
| 14 | S19 · Testing in CI/CD | `labs/day-2/19-testing-cicd/` | **CI** — the whole ladder as pipeline jobs |
| 15 | S20–S26 | `labs/day-3/**`, `examples/capstone/` | stacks → codegen → ordering → filtering → capstone |

**Three Day-1 sections carry no stage number.** The Day-1 fit plan skips S09 and
S10, and S11 is hidden in the 3-day cut, so all three sit outside the Day-1 stage
sequence. This is a Day-1 statement only — being skippable does not by itself
remove a section from the map: S18 is hidden yet holds stage 13, S25 sits inside
stage 15's S20–S26 span, and the S27/S28 appendices have no stage.

S09 is not outside the *project*, though: if it is delivered, the
`local_file.manifest` in `labs/day-1/09-best-practices/` **is** the spine address
and must keep that name. S10 and S11 stand apart from the project by design.

### What "one evolving project" means here

Labs do **not** share one mutating directory. Two physical constraints forbid it:

1. Every lab runs standalone from its own tracked workdir
   (`task lab:validate DIR=labs/day-N/NN-topic`) — the lab workdir contract in
   `AGENT.md`.
2. The drift gate in `scripts/verify.sh` byte-compares an annotated slide or lab
   block against the **whole** source file, so a directory that mutates between
   sections has no stable snapshot for a slide to cite.

Continuity is therefore carried by **addresses**, not by files:

- **Project spine — carried forward, never renamed, never silently dropped:**
  `local_file.manifest`, `variable "service"`, `variable "environment"`,
  `output "manifest_path"`. Once a stage introduces a spine address, every later
  Day-1 stage still declares it — with **one deliberate exception, stage 8**.
  S07 teaches modules by *extracting* the manifest into
  `./modules/service-manifest`, so there the spine lives inside the child module
  and the root reaches it through the instances:
  `module.checkout.local_file.manifest`,
  `module.payments.local_file.manifest`, each instance's own `manifest_path`
  output, and `service`/`environment` passed in as module arguments. The names
  never change; only the prefix does. That extraction *is* the lesson, which is
  why stage 8 needs framing and no structural edit.
- **Auxiliary — demonstration resources whose teaching purpose ends** (for
  example `local_file.summary`, which exists only to give the dependency-graph
  beat a second node): may be retired, but **only explicitly**, with the lab
  preamble naming what was retired and why. A silent disappearance is a defect.

A stage conforms when its diff from the previous stage reads as *spine + an
explicit auxiliary delta*.

**Where the spine's first `variable` lands — decided.** The Day-1 continuity
pass (US-C-STAGE-D1a) settled this: **the spine arrives in two instalments.**
`local_file.manifest` and `output "manifest_path"` are introduced at **stage 1**
(`labs/day-1/01-iac-fork/`); `variable "service"` and `variable "environment"` at
**stage 4** (`labs/day-1/06-variables/`), where S06 teaches typed, validated
inputs and they become the project's own. Stage 2 does teach the `variable` block
type, but the variable it declares — `variable "owner"` — is **auxiliary and
keeps a non-spine name**, and stage 3 retires it explicitly in its preamble.
Stage 3 therefore still declares no variables, which is deliberate: its whole
skill is reading a plan.

The alternative — giving stage 3 `variable "service"` / `variable "environment"`
so a stage-2 spine input could carry forward — was rejected because it would
force S06 to *re-type* a spine address from `string` to `object({…})`, teaching
the opposite of "the spine is stable", and because it would have required
inventing a stage-2 `variable "environment"` that no plan sanctions. Naming it
`variable "service"` at stage 2 and letting it vanish at stage 3 was never an
option: that is exactly the silent spine drop the rule above forbids.

**A stage is not the previous stage's files plus more.** The tree contradicts a
file-superset reading at **six of the seven** Day-1 transitions. Every drop below
is named in the receiving lab's preamble:

- 2 → 3 drops `variable "owner"`, `locals`, `data.local_file.motd` and
  `module "greeting"` — the block-taxonomy demonstrations — and adds
  `local_file.summary` as the dependency graph's second node;
- 3 → 4 drops `random_pet.env` and `local_file.summary`, because every manifest
  field now comes from a typed variable;
- 4 → 5 drops `variable "api_token"` and the outputs `effective_environment` and
  `api_token`, and brings `random_pet.env` back — a postcondition needs a
  non-sensitive value that is unknown at plan;
- 5 → 6 drops both guard variables (`max_manifest_bytes`, `min_secret_length`)
  and the `precondition`/`postcondition`/`check` blocks they fed;
- 6 → 7 drops `random_pet.env`, `output "db_password"` and the explicit
  `backend "local"` block, and *introduces* `variable "state_passphrase"`;
- 7 → 8 drops `variable "state_passphrase"` and `random_password.session`, and
  moves the spine inside `./modules/service-manifest`.

Only 1 → 2 retires nothing at all — it is the one pure superset.

S04 and S05 also teach deliberately *against* a small config, so a growing-only
config would work against the beat. Judge a stage by the spine + explicit
retirement rule above — never by counting files.

### Showing a transition on a slide

Progressive code transitions use the pattern the repo already ships and
drift-checks: a `code-walkthrough` whose `magic-move` container holds
consecutive annotated fences, each byte-checked against its own whole file. The
worked reference is `slides-templates.md:123-172` over
`labs/fixtures/templates-demo/naming-step-1.tf`, `naming-step-2.tf` and
`naming-step-3.tf`. Step snapshots for that purpose belong under
`labs/fixtures/` (the carve-out in `AGENT.md`) — never as an excerpt of a lab
workdir file, which the whole-file drift gate rejects.

## Superset vs canonical 3-day cut

The section library (**S00–S28**) is a **content superset** — larger than three
days on purpose. Delivery boils down via `hide:` toggles and the Day 1 fit plan
in the [README](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md#scope-and-timing-known-issue).

- **Tier:** `core` (always in the cut) · `recommended` (keep if time) · `optional` (cut first).
- **Canonical cut:** [slides-3day.md](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/slides-3day.md) — serve with `task dev:3day`.
- **Day totals (slides + labs, unrehearsed planning estimates)** against a 390 min/day budget, from `canonicalDayTotals()`: **Day 1 = 770 (525 + 245), +380 over** · **Day 2 = 360 (180 + 180), 30 under** · **Day 3 = 400 (200 + 200), +10 over**. Published in the [README](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md#published-day-totals) and the [runbook](facilitator-runbook.md#live-cut-order).
- **Day 1 and Day 3 do not fit.** The README fit plan compresses Day-1 *slide* time from 655 to 390; the 245 minutes of Day-1 labs sit on top, so a fit-plan Day 1 is still 635 of slides + labs. Apply it before facilitating, and plan the overflow.

## Section map (S00–S28)

| ID | Section | Tier | Day | Status | 3-day cut |
| --- | --- | ---: | --- | --- | --- |
| S00 | Welcome & setup | core | 1 | authored | Compress (fit plan) |
| S01 | Infrastructure as Code | core | 1 | authored | Compress |
| S02 | HCL & building blocks | core | 1 | authored | Compress |
| S03 | The core workflow | core | 1 | authored | Compress |
| S06 | Variables, validation & types | core | 1 | authored | Compress |
| S15 | Validation, preconditions & checks | core | 1 | authored | Compress (keep blocking + `check`) |
| S04 | State | core | 1 | authored | Compress |
| S05 | State encryption | core | 1 | authored | Compress |
| S07 | Modules | core | 1 | authored | Compress |
| S08 | Naming & labelling module | core | 1 | authored | Keep |
| S09 | Best practices | recommended | 1 | authored | Skip (fit plan) |
| S10 | OpenTofu differentiators | recommended | 1 | authored | Skip (fit plan) |
| S11 | The TACO landscape | optional | 1 | authored | Skip (`hide`) |
| S12 | Why test IaC + testing pyramid | core | 2 | authored | Keep |
| S13 | Static analysis & formatting | core | 2 | authored | Keep |
| S14 | Security & policy scanners | core | 2 | authored | Keep |
| S16 | Native testing — `tofu test` | core | 2 | authored | Keep |
| S17 | Mocking providers | core | 2 | authored | Keep |
| S18 | Integration, e2e & cost | optional | 2 | authored | Skip (`hide`) |
| S19 | Testing in CI/CD | recommended | 2 | authored | Keep |
| S20 | Why Terramate | core | 3 | authored | Keep |
| S21 | Stacks | core | 3 | authored | Keep |
| S22 | Code generation | core | 3 | authored | Keep |
| S23 | Orchestration & ordering | core | 3 | authored | Keep |
| S24 | Change detection & filtering | recommended | 3 | authored | Keep / skip if short |
| S25 | Terramate in CI + Cloud | optional | 3 | authored | Skip (`hide`) unless time |
| S26 | Capstone & wrap-up | core | 3 | authored | Keep |
| S27 | Terragrunt vs Terramate | optional | 3 | authored | Skip (`hide`) — appendix |
| S28 | Ecosystem tooling | optional | 3 | authored | Skip (`hide`) — appendix |

## Section timings (planning estimates)

Slides and lab minutes are **unrehearsed planning estimates** from
`scripts/deck-manifest.mjs`. Day 1 fit-plan compression lives in the README and
`slides-3day.md` markers — not in this table. Summing the rows the section map
marks as kept in the three-day cut — that is, excluding S09, S10 and S11 (Day 1),
S18 (Day 2) and S25, S27 and S28 (Day 3) — gives that day's published total above.

| ID | Section | Slides | Lab |
| --- | --- | ---: | ---: |
| S00 | Welcome & setup | 40 | 20 |
| S01 | Infrastructure as Code | 40 | 20 |
| S02 | HCL & building blocks | 50 | 20 |
| S03 | The core workflow | 60 | 20 |
| S06 | Variables, validation & types | 50 | 25 |
| S15 | Validation, preconditions & checks | 50 | 30 |
| S04 | State | 50 | 20 |
| S05 | State encryption | 60 | 25 |
| S07 | Modules | 60 | 35 |
| S08 | Naming & labelling module | 65 | 30 |
| S09 | Best practices | 50 | 30 |
| S10 | OpenTofu differentiators | 45 | 25 |
| S11 | The TACO landscape | 35 | 20 |
| S12 | Why test IaC + testing pyramid | 20 | 20 |
| S13 | Static analysis & formatting | 30 | 30 |
| S14 | Security & policy scanners | 35 | 35 |
| S16 | Native testing — `tofu test` | 35 | 35 |
| S17 | Mocking providers | 30 | 30 |
| S18 | Integration, e2e & cost | 30 | 30 |
| S19 | Testing in CI/CD | 30 | 30 |
| S20 | Why Terramate | 25 | 25 |
| S21 | Stacks | 30 | 30 |
| S22 | Code generation | 30 | 30 |
| S23 | Orchestration & ordering | 30 | 30 |
| S24 | Change detection & filtering | 25 | 25 |
| S25 | Terramate in CI + Cloud | 25 | 25 |
| S26 | Capstone & wrap-up | 60 | 60 |
| S27 | Terragrunt vs Terramate | 20 | 20 |
| S28 | Ecosystem tooling | 20 | 20 |

Canonical visible Day 1 order after fit-plan skips:
`S00 → S01 → S02 → S03 → S06 → S15 → S04 → S05 → S07 → S08`.

**Section covers vs delivery position.** Cover art is referenced by section ID in
each `pages/SNN-*/index.md` frontmatter, so every cover still resolves — but the
file names carry a narrative arc that was numbered against the *old* Day-1
order, and after US-C-RESEQ the names no longer read in sequence. The art is
deliberately **not** renamed or recreated; use this mapping instead.

| Delivery position | Section | Cover file | Narrative name |
| ---: | --- | --- | --- |
| 1 | S00 | `public/covers/section-00-arrival.png` | Arrival |
| 2 | S01 | `public/covers/section-01-the-two-blueprints.png` | The two blueprints |
| 3 | S02 | `public/covers/section-02-the-first-prefabs.png` | The first prefabs |
| 4 | S03 | `public/covers/section-03-plan-then-raise.png` | Plan then raise |
| 5 | S06 | `public/covers/section-06-calibrating-the-instruments.png` | Calibrating the instruments |
| 6 | S15 | `public/covers/section-15-the-checkpoint-gates.png` | The checkpoint gates |
| 7 | S04 | `public/covers/section-04-the-great-survey-map.png` | The great survey map |
| 8 | S05 | `public/covers/section-05-sealing-the-ledger.png` | Sealing the ledger |
| 9 | S07 | `public/covers/section-07-the-parts-depot.png` | The parts depot |
| 10 | S08 | `public/covers/section-08-tagging-the-works.png` | Tagging the works |
| — (skipped) | S09 | `public/covers/section-09-the-tidy-worksite.png` | The tidy worksite |
| — (skipped) | S10 | `public/covers/section-10-the-advanced-rig.png` | The advanced rig |
| — (skipped) | S11 | `public/covers/section-11-the-contractors-fair.png` | The contractors' fair |

Day 2: `S12 → S13 → S14 → S16 → S17 → S19`.

Day 3: `S20 → S21 → S22 → S23 → S24 → S26` (+ optional S25; S27 and S28 are
hidden appendices — Terragrunt comparison and ecosystem tooling, superset only).

## Related

- [Labs by day](labs.md)
- [Live decks & PDFs](downloads.md)
- [Associate alignment](associate-alignment.md) (design check, not exam prep)
