# Rehearsal Checklist — LocalStack + mock path, lab by lab

A pre-delivery **dry-run** checklist for the facilitator. It walks the workshop's
**fullest runnable path** end to end — mock-only steps plus every LocalStack step and
Day-2/3 tool lane the canonical cut needs — so toolchain installs, deliberate break→fix
beats, and **Cleanup / panic reset** sections are all exercised once on a clean machine
**before** anyone is in the room.

Why the full path: a mock-only rehearsal never exercises LocalStack health, scanner CLIs,
or Terramate ordering. Rehearsing the fullest path covers everything; a mock-only delivery
is then a subset. See the [facilitator runbook](./facilitator-runbook.md) for preflight
and the [validation matrix](./validation-matrix.md) for per-lab environment/tool claims.

> **Scope.** This checklist covers **every contracted participant lab (S00–S28)**, not just
> the 3-day cut, because a rehearsal should exercise the whole authored superset. The
> **Tier** column marks what is `core` / `recommended` / `optional` so you can skip
> cut-first sections when rehearsing a specific delivery.

Two more things to keep straight before you start:

> **This is a checklist, not a results log.** Record measured timings and blockers in the
> separate [timing-results template](./timing-results-template.md) — keep measured numbers
> out of this file. This checklist complements the
> [validation matrix](./validation-matrix.md): that matrix tracks per-lab validation state;
> this checklist is the human walk-through of the delivery path.

## How to use this checklist

1. On a fresh machine (or fresh user account): `task setup`, confirm `tofu version` ≥1.9.
2. Before the first `localstack ✓` step: `task lab:up` and confirm
   <http://localhost:4566/_localstack/health>.
3. Work top to bottom. For each section: run slides in one window, do the lab in another,
   install any tool **before** the step that needs it, hit the deliberate **break→fix**, then
   run **Cleanup / panic reset**.
4. Tick the boxes as you go. Log numbers in the
   [timing-results template](./timing-results-template.md), not here.
5. By authoring contract, every runnable lab carries a deliberate break→fix and ends with
   **Cleanup / panic reset** (S11 is paper-only — no `tofu` cleanup).

## Pre-flight (once, before Section S00)

- [ ] OpenTofu ≥1.9 on `PATH` (`task setup`).
- [ ] Docker running (or k8s LocalStack route documented in `setup/localstack.md`).
- [ ] For Day 2: TFLint, Trivy, Checkov, Conftest on `PATH` when rehearsing S13–S14.
- [ ] For Day 3: Terramate CLI (`terramate version`) when rehearsing S20–S25.
- [ ] Optional S18: Go + Terratest lane if you plan to teach the integration stretch.

## Day 1 — Author → guard → package

| ✓ | ID | Tier | Lab | Tools / deps first | break→fix present | Cleanup runs |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | S00 | core | [00-setup](../labs/day-1/00-setup.md) | `task lab:up` before LocalStack | wrong provider / health fail | [ ] |
| [ ] | S01 | core | [01-iac-fork](../labs/day-1/01-iac-fork.md) | none | fork choice / wrong mental model | [ ] |
| [ ] | S02 | core | [02-hcl-blocks](../labs/day-1/02-hcl-blocks.md) | none | invalid block / type error | [ ] |
| [ ] | S03 | core | [03-core-workflow](../labs/day-1/03-core-workflow.md) | none | plan surprise / wrong target | [ ] |
| [ ] | S06 | core | [06-variables](../labs/day-1/06-variables.md) | none | validation failure / wrong type | [ ] |
| [ ] | S15 | core | [15-conditions-checks](../labs/day-1/15-conditions-checks.md) | none | precondition / check block | [ ] |
| [ ] | S04 | core | [04-state](../labs/day-1/04-state.md) | none | state drift / wrong backend assumption | [ ] |
| [ ] | S05 | core | [05-state-encryption](../labs/day-1/05-state-encryption.md) | none | encryption mis-config | [ ] |
| [ ] | S07 | core | [07-modules](../labs/day-1/07-modules.md) | none | module input/output mismatch | [ ] |
| [ ] | S08 | core | [08-naming-labels](../labs/day-1/08-naming-labels.md) | LocalStack for Step 4 | naming rule violation | [ ] |
| [ ] | S09 | recommended | [09-best-practices](../labs/day-1/09-best-practices.md) | none | anti-pattern in config | [ ] |
| [ ] | S10 | recommended | [10-differentiators](../labs/day-1/10-differentiators.md) | LocalStack | feature contrast step fails | [ ] |
| [ ] | S11 | optional | [11-taco-landscape](../labs/day-1/11-taco-landscape.md) | none (paper) | n/a — decision exercise | n/a |

**Day 1 LocalStack:** confirm `task lab:up` before S00 bucket step and S08 Step 4 / S10.

## Day 2 — Test pyramid → scanners → CI honesty

| ✓ | ID | Tier | Lab | Tools / deps first | break→fix present | Cleanup runs |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | S12 | core | [12-testing-pyramid](../labs/day-2/12-testing-pyramid.md) | none | test layer mismatch | [ ] |
| [ ] | S13 | core | [13-static-analysis](../labs/day-2/13-static-analysis.md) | **TFLint** | messy fixture lint fail | [ ] |
| [ ] | S14 | core | [14-security-scanners](../labs/day-2/14-security-scanners.md) | **Trivy / Checkov / Conftest** | scanner/policy finding | [ ] |
| [ ] | S16 | core | [16-tofu-test](../labs/day-2/16-tofu-test.md) | LocalStack for integration | failing assert | [ ] |
| [ ] | S17 | core | [17-mocking](../labs/day-2/17-mocking.md) | none | mock provider mismatch | [ ] |
| [ ] | S18 | optional | [18-terratest-cost](../labs/day-2/18-terratest-cost.md) | LocalStack; optional Go | cost/integration skip path | [ ] |
| [ ] | S19 | recommended | [19-testing-cicd](../labs/day-2/19-testing-cicd.md) | none (fixture YAML) | CI gate mis-order | [ ] |

## Day 3 — Terramate → capstone

| ✓ | ID | Tier | Lab | Tools / deps first | break→fix present | Cleanup runs |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | S20 | core | [20-why-terramate](../labs/day-3/20-why-terramate.md) | **Terramate** | stack graph surprise | [ ] |
| [ ] | S21 | core | [21-stacks](../labs/day-3/21-stacks.md) | **Terramate** | wrong stack selected | [ ] |
| [ ] | S22 | core | [22-codegen](../labs/day-3/22-codegen.md) | **Terramate** | codegen drift | [ ] |
| [ ] | S23 | core | [23-orchestration](../labs/day-3/23-orchestration.md) | **Terramate** | ordering violation | [ ] |
| [ ] | S24 | recommended | [24-change-detection](../labs/day-3/24-change-detection.md) | **Terramate** | filter misses change | [ ] |
| [ ] | S25 | optional | [25-terramate-ci-cloud](../labs/day-3/25-terramate-ci-cloud.md) | none (fixture) | cloud/CI wiring gap | [ ] |
| [ ] | S26 | core | [26-capstone](../labs/day-3/26-capstone.md) | LocalStack for AWS steps | capstone audit finding | [ ] |
| [ ] | S27 | optional | [27-terragrunt-comparison](../labs/day-3/27-terragrunt-comparison.md) | none (read-only fixture) | TACO/state-host claim | [ ] |
| [ ] | S28 | optional | [28-ecosystem-tooling](../labs/day-3/28-ecosystem-tooling.md) | **pre-commit** (+ one-time hook fetch) | dirty fixture vs fixing hooks | [ ] |

## Post-rehearsal wrap-up

- [ ] Every lab's **Cleanup / panic reset** left no stray state under `labs/**` workdirs.
- [ ] `task lab:down` / LocalStack teardown works as documented.
- [ ] Tool installs (TFLint, scanners, Terramate) completed within workable time — record
      durations in the [timing-results template](./timing-results-template.md).
- [ ] Any lab where break→fix or cleanup did **not** match the doc is filed as a
      [beta-feedback issue](../.github/ISSUE_TEMPLATE/beta-feedback.yml).
- [ ] Update [`docs/validation-matrix.md`](./validation-matrix.md) validation states only
      after a deliberate maintainer decision (never via automation alone).
