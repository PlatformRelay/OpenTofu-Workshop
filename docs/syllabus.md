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

## Superset vs canonical 3-day cut

The section library (**S00–S26**) is a **content superset** — larger than three
days on purpose. Delivery boils down via `hide:` toggles and the Day 1 fit plan
in the [README](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md#scope-and-timing-known-issue).

- **Tier:** `core` (always in the cut) · `recommended` (keep if time) · `optional` (cut first).
- **Canonical cut:** [slides-3day.md](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/slides-3day.md) — serve with `task dev:3day`.
- **Day 1** overflows a raw full-section budget; apply the README fit plan before facilitating.
- **Day 2–3** full-section minute totals are not published in-repo yet — pace from lab durations and presenter notes (see the runbook). Do not invent day totals.

## Section map (S00–S26)

| ID | Section | Tier | Day | 3-day cut |
| --- | --- | ---: | --- | --- |
| S00 | Welcome & setup | core | 1 | Compress (fit plan) |
| S01 | Infrastructure as Code | core | 1 | Compress |
| S02 | HCL & building blocks | core | 1 | Compress |
| S03 | The core workflow | core | 1 | Compress |
| S04 | State | core | 1 | Compress |
| S05 | State encryption | core | 1 | Compress |
| S06 | Variables, validation & types | core | 1 | Compress |
| S15 | Validation, preconditions & checks | core | 1 | Compress (keep blocking + `check`) |
| S07 | Modules | core | 1 | Compress |
| S08 | Naming & labelling module | core | 1 | Keep |
| S09 | Best practices | recommended | 1 | Skip (fit plan) |
| S10 | OpenTofu differentiators | recommended | 1 | Skip (fit plan) |
| S11 | The TACO landscape | optional | 1 | Skip (`hide`) |
| S12 | Why test IaC + testing pyramid | core | 2 | Keep |
| S13 | Static analysis & formatting | core | 2 | Keep |
| S14 | Security & policy scanners | core | 2 | Keep |
| S16 | Native testing — `tofu test` | core | 2 | Keep |
| S17 | Mocking providers | core | 2 | Keep |
| S18 | Integration, e2e & cost | optional | 2 | Skip (`hide`) |
| S19 | Testing in CI/CD | recommended | 2 | Keep |
| S20 | Why Terramate | core | 3 | Keep |
| S21 | Stacks | core | 3 | Keep |
| S22 | Code generation | core | 3 | Keep |
| S23 | Orchestration & ordering | core | 3 | Keep |
| S24 | Change detection & filtering | recommended | 3 | Keep / skip if short |
| S25 | Terramate in CI + Cloud | optional | 3 | Skip (`hide`) unless time |
| S26 | Capstone & wrap-up | core | 3 | Keep |

Canonical visible Day 1 order after fit-plan skips:
`S00 → S01 → S02 → S03 → S04 → S05 → S06 → S15 → S07 → S08`.

Day 2: `S12 → S13 → S14 → S16 → S17 → S19`.

Day 3: `S20 → S21 → S22 → S23 → S24 → S26` (+ optional S25).

## Related

- [Labs by day](labs.md)
- [Live decks & PDFs](downloads.md)
- [Associate alignment](associate-alignment.md) (design check, not exam prep)
