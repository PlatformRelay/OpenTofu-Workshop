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

### Stage map

Stage numbers are the **target** teaching sequence. Section IDs never change —
nothing is renumbered. The live delivery order is the one published under
[Section timings](#section-timings-planning-estimates); it converges on the
stage order when the Day-1 resequencing lands.

**Where each concept is introduced:** `resource` → stage 0 · `variable` →
stage 4 · `output` → stage 1 · `plan` → stage 0 (read line by line at stage 3) ·
`apply` → stage 0 (full lifecycle at stage 3) · state → stage 6 · modules →
stage 8 · testing → stage 10 · CI → stage 14.

| Stage | Section | Workdir | Introduces |
| --- | --- | --- | --- |
| 0 | S00 · Welcome & setup | `labs/day-1/00-setup/` | **`resource`**, `init`, the first **`plan`** and **`apply`** |
| 0b | S00 · stretch | `labs/day-1/00-setup/` | the first cloud-shaped resource (S3 on LocalStack) |
| 1 | S01 · Infrastructure as Code | `labs/day-1/01-iac-fork/` | declarative vs imperative; **`output`** |
| 2 | S02 · HCL & building blocks | `labs/day-1/02-hcl-blocks/` | block taxonomy, `locals`, `data`, references |
| 3 | S03 · The core workflow | `labs/day-1/03-core-workflow/` | the four-command loop — **plan diffs**, the graph, `destroy` |
| 4 | S06 · Variables, validation & types | `labs/day-1/06-variables/` | **`variable`** — typed, validated, sensitive |
| 5 | S15 · Validation, preconditions & checks | `labs/day-1/15-conditions-checks/` | `precondition`, `postcondition`, `check` |
| 6 | S04 · State | `labs/day-1/04-state/` | **state**, drift, backends |
| 7 | S05 · State encryption | `labs/day-1/05-state-encryption/` | encrypted state and encrypted plan |
| 8 | S07 · Modules | `labs/day-1/07-modules/` | **`module`** — `./modules/service-manifest` consumed twice |
| 9 | S08 · Naming & labelling | `examples/naming-labels-demo/` | one naming + labelling taxonomy |
| 10 | S12, S13 | `labs/day-2/12-testing-pyramid/`, `13-static-analysis/` | **testing** — the pyramid, `fmt`, TFLint, pre-commit |
| 11 | S14 · Security & policy scanners | `labs/day-2/14-security-scanners/` | policy + security scanning (planted insecure fixture — deliberately *not* the learner's project) |
| 12 | S16, S17 | `labs/day-2/16-tofu-test/`, `17-mocking/` | native `tofu test`, `mock_provider` |
| 13 | S18 · Integration, e2e & cost | `labs/day-2/18-terratest-cost/` | integration + cost (optional tier) |
| 14 | S19 · Testing in CI/CD | `labs/day-2/19-testing-cicd/` | **CI** — the whole ladder as pipeline jobs |
| 15 | S20–S26 | `labs/day-3/**`, `examples/capstone/` | stacks → codegen → ordering → filtering → capstone |

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
  Day-1 stage still declares it.
- **Auxiliary — demonstration resources whose teaching purpose ends** (for
  example `local_file.summary`, which exists only to give the dependency-graph
  beat a second node): may be retired, but **only explicitly**, with the lab
  preamble naming what was retired and why. A silent disappearance is a defect.

A stage conforms when its diff from the previous stage reads as *spine + an
explicit auxiliary delta*.

**A stage is not the previous stage's files plus more.** The tree contradicts a
file-superset reading at five transitions:

- 3 → 4 drops `random_pet.release`, `local_file.summary` and
  `output "release_name"`;
- 4 → 5 drops `variable "api_token"` and two outputs;
- 5 → 6 shares nothing — `labs/day-1/04-state/` declares no variables at all;
- 6 → 7 keeps only a password resource and a passphrase variable;
- 7 → 8 drops `variable "state_passphrase"` and `random_password.db`.

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
- **Day 1** overflows a raw full-section budget; apply the README fit plan before facilitating.
- **Day 2–3** full-section minute totals are not published in-repo yet — pace from lab durations and presenter notes (see the runbook). Do not invent day totals.

## Section map (S00–S28)

| ID | Section | Tier | Day | Status | 3-day cut |
| --- | --- | ---: | --- | --- | --- |
| S00 | Welcome & setup | core | 1 | authored | Compress (fit plan) |
| S01 | Infrastructure as Code | core | 1 | authored | Compress |
| S02 | HCL & building blocks | core | 1 | authored | Compress |
| S03 | The core workflow | core | 1 | authored | Compress |
| S04 | State | core | 1 | authored | Compress |
| S05 | State encryption | core | 1 | authored | Compress |
| S06 | Variables, validation & types | core | 1 | authored | Compress |
| S15 | Validation, preconditions & checks | core | 1 | authored | Compress (keep blocking + `check`) |
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
`slides-3day.md` markers — not in this table.

| ID | Section | Slides | Lab |
| --- | --- | ---: | ---: |
| S00 | Welcome & setup | 40 | 20 |
| S01 | Infrastructure as Code | 40 | 20 |
| S02 | HCL & building blocks | 50 | 20 |
| S03 | The core workflow | 60 | 20 |
| S04 | State | 50 | 20 |
| S05 | State encryption | 60 | 25 |
| S06 | Variables, validation & types | 50 | 25 |
| S15 | Validation, preconditions & checks | 50 | 30 |
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
`S00 → S01 → S02 → S03 → S04 → S05 → S06 → S15 → S07 → S08`.

Day 2: `S12 → S13 → S14 → S16 → S17 → S19`.

Day 3: `S20 → S21 → S22 → S23 → S24 → S26` (+ optional S25; S27 and S28 are
hidden appendices — Terragrunt comparison and ecosystem tooling, superset only).

## Related

- [Labs by day](labs.md)
- [Live decks & PDFs](downloads.md)
- [Associate alignment](associate-alignment.md) (design check, not exam prep)
