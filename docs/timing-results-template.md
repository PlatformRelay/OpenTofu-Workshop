# Timing-Results Template — per-section MEASURED timings

A blank template for recording **measured** timings during a rehearsal or beta run. Copy
this file (e.g. to `timing-results-2026-08-15.md`), fill the **MEASURED** columns as you
run, and keep it as the record for that run.

> **Measured ≠ planned.** The `PLANNED` columns are copied from the
> [syllabus](./syllabus.md#section-timings-planning-estimates) — they are **unrehearsed
> planning estimates**, not facts. The `MEASURED` columns start **empty** and hold **only
> observed stopwatch numbers**. **Never** copy a planned value into a measured column.

## Run metadata

Fill this in per run:

- **Run date:** _(YYYY-MM-DD)_
- **Facilitator / timer:** _(who kept the clock)_
- **Environment:** _(mock-only / LocalStack Docker / LocalStack k8s / mixed)_
- **Cut delivered:** _(canonical 3-day cut / custom — list sections actually run)_
- **Host notes:** _(OS, OpenTofu version, Docker/LocalStack health quirks)_

## How to fill this in

1. Time **slides** and **lab** separately; record whole minutes in `MEASURED slides` and
   `MEASURED lab`.
2. `Δ slides` / `Δ lab` = **measured − planned** (blank until measured). Positive = over estimate.
3. Put slow tool installs, broken commands, or room stumbles in **Blockers / notes**.
4. Leave a cell **empty** if you did not run or time that section.

## Legend

- **PLANNED** — from the syllabus; do not edit these.
- **MEASURED** — observed stopwatch minutes. Empty = not measured.
- **Δ** — measured minus planned; blank until measured.
- **`—`** — not applicable (S11 paper-only has no `tofu` lab timing split).

## Day 1

| ID | Section | PLANNED slides | PLANNED lab | MEASURED slides | MEASURED lab | Δ slides | Δ lab | Blockers / notes |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- |
| S00 | Welcome & setup | 40 | 20 | | | | | |
| S01 | Infrastructure as Code | 40 | 20 | | | | | |
| S02 | HCL & building blocks | 50 | 20 | | | | | |
| S03 | The core workflow | 60 | 20 | | | | | |
| S06 | Variables, validation & types | 50 | 25 | | | | | |
| S15 | Validation, preconditions & checks | 50 | 30 | | | | | |
| S04 | State | 50 | 20 | | | | | |
| S05 | State encryption | 60 | 25 | | | | | |
| S07 | Modules | 60 | 35 | | | | | |
| S08 | Naming & labelling module | 65 | 30 | | | | | |
| S09 | Best practices | 50 | 30 | | | | | |
| S10 | OpenTofu differentiators | 55 | 55 | | | | | |
| S11 | The TACO landscape | 35 | 20 | | — | | — | Paper exercise — lab column n/a. |

## Day 2

| ID | Section | PLANNED slides | PLANNED lab | MEASURED slides | MEASURED lab | Δ slides | Δ lab | Blockers / notes |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- |
| S12 | Why test IaC + testing pyramid | 20 | 20 | | | | | |
| S13 | Static analysis & formatting | 30 | 30 | | | | | |
| S14 | Security & policy scanners | 35 | 35 | | | | | |
| S16 | Native testing — `tofu test` | 35 | 35 | | | | | |
| S17 | Mocking providers | 30 | 30 | | | | | |
| S18 | Integration, e2e & cost | 30 | 30 | | | | | |
| S19 | Testing in CI/CD | 30 | 30 | | | | | |

## Day 3

| ID | Section | PLANNED slides | PLANNED lab | MEASURED slides | MEASURED lab | Δ slides | Δ lab | Blockers / notes |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- |
| S20 | Why Terramate | 25 | 25 | | | | | |
| S21 | Stacks | 30 | 30 | | | | | |
| S22 | Code generation | 30 | 30 | | | | | |
| S23 | Orchestration & ordering | 30 | 30 | | | | | |
| S24 | Change detection & filtering | 25 | 25 | | | | | |
| S25 | Terramate in CI + Cloud | 25 | 25 | | | | | |
| S26 | Capstone & wrap-up | 60 | 60 | | | | | |

## Day totals (measured vs planned)

Day 1 planned totals assume the README fit-plan compression — your measured total should
note which sections you actually ran.

| Day | PLANNED total (sections above) | MEASURED total (this run) | Δ | Sections run this run |
| --- | ---: | --- | --- | --- |
| Day 1 | _(sum your PLANNED rows)_ | | | |
| Day 2 | _(sum your PLANNED rows)_ | | | |
| Day 3 | _(sum your PLANNED rows)_ | | | |

> **Reading the deltas.** The open pre-delivery question is whether the canonical cut lands
> near **~390 min/day at ~50/50 slides:lab**. That can only be answered from the MEASURED
> column — not from syllabus estimates alone.

## Blockers summary

List cross-cutting blockers (LocalStack slow start, scanner install, Terramate version skew).
File each as a [beta-feedback issue](../.github/ISSUE_TEMPLATE/beta-feedback.yml) and link here.

- _(none recorded yet — fill during the run)_
