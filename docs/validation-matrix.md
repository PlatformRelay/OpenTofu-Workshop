# Clean-environment lab validation matrix

A single, tracked table mapping **every** contracted participant lab
(`labs/day-{1,2,3}/NN-*.md` from `scripts/lab-contract.mjs`) to the environment(s) it
supports, the laptop/cluster tools it needs, the reproducibility-critical pins it
references, and its **honest current validation state**. It is the **human source of
truth** for lab validation metadata; [`infra/lab-inventory.json`](../infra/lab-inventory.json)
is the generated machine-readable view (regenerate with
`node scripts/lab-inventory.mjs --write`, CI `--check` rejects drift). This matrix also
doubles as rehearsal tracking for the manual clean-environment rehearsal (**US-P-VALDOCS**).

Source of truth for this matrix: the labs themselves, [`docs/syllabus.md`](./syllabus.md)
(section map), [`docs/facilitator-runbook.md`](./facilitator-runbook.md) (tool preflight),
and [`docs/beta-limitations.md`](./beta-limitations.md) (honest delivery caveats). Nothing
here is invented — every tool and pin is cited from the repo as it ships today.

## How to read this matrix

- **Environment** uses the labs' own badge grammar: `mock ✓ (no docker)` (pure-local
  providers), `localstack ✓` (needs LocalStack on `:4566`), `local ✓ (no docker)` (local
  provider path without Docker), `paper ✓` (decision exercise — no `tofu`), and combinations
  such as `localstack ✓ · mock ✓` where steps split across lanes.
- **Tools / deps** are laptop prerequisites beyond OpenTofu itself — Docker/k8s for
  LocalStack, scanner CLIs, Terramate, optional Go for Terratest. "None" means the runnable
  path needs only `tofu` on `PATH`.
- **Pinned versions / URLs** lists reproducibility-critical pins the lab references.
  Where a lab uses a floating install (`latest`, unpinned chart), that is recorded honestly.

### Validation-state legend

| State | Meaning |
| --- | --- |
| `unit-tested` | The lab workdir (or a sibling example) is exercised in the **unit lane** of `scripts/verify.sh` (`tofu validate` / plan-only `tofu test`). **Not** a full clean-environment rehearsal. |
| `localstack-smoke` | The lab ran end-to-end against a clean LocalStack (or k8s-hosted equivalent) and a maintainer recorded that result. **No lab is in this state yet.** |
| `unrun` | Authored and contract-checked, but **not** rehearsed end-to-end in a clean environment — timings, add-on installs, and verbatim learner output are planning estimates only. |
| `deferred` | Reserved lab ID with no runnable participant path yet. **None in this workshop.** |

> **Honesty rule.** No lab is marked `localstack-smoke`. CI unit tests prove **syntax and
> plan/mock behaviour**, not facilitator-room timing or LocalStack health edge cases. Per
> [`docs/beta-limitations.md`](./beta-limitations.md), the workshop has **not** had a full
> clean-environment rehearsal. Timings and behaviour are **not** claimed here until
> rehearsed using [`docs/rehearsal-checklist.md`](./rehearsal-checklist.md).

## Participant host validation

Host support is a separate claim from lab validation.

| Host path | Automated coverage | Live validation procedure | State |
| --- | --- | --- | --- |
| macOS / Linux + OpenTofu ≥1.9 | `scripts/verify.sh` unit lane, `lab-contract`, deck manifest | Fresh-host `task setup` + `task verify` | `unit-tested` (Day-1 mock path) / `unrun` (LocalStack + tools) |
| Windows 11 + WSL 2 + Ubuntu + Docker Desktop | Documented only | WSL path rehearsal: Lab 00, one LocalStack lab, cleanup | `unrun` |
| Managed device / no Docker | Mock-only labs (`mock ✓`) | Facilitator-issued notes; skip LocalStack steps | `unrun` |

## Canonical toolchain pins

| Key | Value |
| --- | --- |
| OpenTofu | ≥ **1.9** (`setup/bootstrap.sh`) |
| LocalStack | `:4566` health at `/_localstack/health` (`Taskfile.yaml`) |
| Terramate | Spoilers pinned ~**0.17.x** (facilitator runbook) |
| Day-2 scanners | TFLint, Trivy, Checkov, Conftest on `PATH` when teaching S13–S14 |

## The matrix

| Lab | Section | Environment | Tools / deps | Pinned versions / URLs | State |
| --- | --- | --- | --- | --- | --- |
| [`day-1/00-setup.md`](../labs/day-1/00-setup.md) | S00 Welcome & setup | `localstack ✓` · `local ✓ (no docker)` | Docker or k8s LocalStack route | OpenTofu ≥1.9; LocalStack `:4566` | `unrun` |
| [`day-1/01-iac-fork.md`](../labs/day-1/01-iac-fork.md) | S01 Infrastructure as Code | `mock ✓ (no docker)` | None | `local` + `random` providers | `unrun` |
| [`day-1/02-hcl-blocks.md`](../labs/day-1/02-hcl-blocks.md) | S02 HCL & building blocks | `mock ✓ (no docker)` | None | `local` + `random` providers | `unrun` |
| [`day-1/03-core-workflow.md`](../labs/day-1/03-core-workflow.md) | S03 The core workflow | `mock ✓ (no docker)` | None | `local` + `random` providers | `unrun` |
| [`day-1/06-variables.md`](../labs/day-1/06-variables.md) | S06 Variables, validation & types | `mock ✓ (no docker)` | None | `local` + `random` providers | `unrun` |
| [`day-1/15-conditions-checks.md`](../labs/day-1/15-conditions-checks.md) | S15 Validation, preconditions & checks | `mock ✓ (no docker)` | None | `local` + `random` providers | `unrun` |
| [`day-1/04-state.md`](../labs/day-1/04-state.md) | S04 State | `mock ✓ (no docker)` · `localstack ✓ (Stretch)` | Docker for the S3-backend Stretch | `random` + `local` providers; Stretch: OpenTofu ≥1.10 (`use_lockfile`), LocalStack `:4566` | `unrun` |
| [`day-1/05-state-encryption.md`](../labs/day-1/05-state-encryption.md) | S05 State encryption | `localstack ✓` · `mock ✓` | None for mock path; Docker for optional Step 6 (KMS) | `local` + `random` providers; pbkdf2 keys local, optional `aws_kms` via LocalStack `:4566` | `unrun` |
| [`day-1/07-modules.md`](../labs/day-1/07-modules.md) | S07 Modules | `mock ✓ (no docker)` | None | `local` + `random` providers | `unrun` |
| [`day-1/08-naming-labels.md`](../labs/day-1/08-naming-labels.md) | S08 Naming & labelling module | `localstack ✓` · `mock ✓` | Docker for Step 4 LocalStack path | `modules/naming`; LocalStack AWS provider | `unrun` |
| [`day-1/09-best-practices.md`](../labs/day-1/09-best-practices.md) | S09 Best practices | `mock ✓ (no docker)` | None (`unzip` optional) | `local` + `archive` providers | `unrun` |
| [`day-1/10-differentiators.md`](../labs/day-1/10-differentiators.md) | S10 OpenTofu differentiators | `localstack ✓` | Docker + LocalStack (`awslocal` via the container in Part B) | OpenTofu ≥1.9; `:4566` | `unrun` |
| [`day-1/11-taco-landscape.md`](../labs/day-1/11-taco-landscape.md) | S11 The TACO landscape | `paper ✓` | None (pen / notes) | n/a | `unrun` |
| [`day-2/12-testing-pyramid.md`](../labs/day-2/12-testing-pyramid.md) | S12 Why test IaC + testing pyramid | `mock ✓ (no docker)` | None | in-lab `main.tftest.hcl` | `unit-tested` |
| [`day-2/13-static-analysis.md`](../labs/day-2/13-static-analysis.md) | S13 Static analysis & formatting | `mock ✓ (no docker)` | **TFLint** on `PATH` | intentional messy fixture (S13) | `unrun` |
| [`day-2/14-security-scanners.md`](../labs/day-2/14-security-scanners.md) | S14 Security & policy scanners | `mock ✓ (no docker)` | **Trivy**, **Checkov**, **Conftest** | scanner CLIs unpinned on laptop | `unrun` |
| [`day-2/16-tofu-test.md`](../labs/day-2/16-tofu-test.md) | S16 Native testing — `tofu test` | `localstack ✓` · `plan ✓` | Docker for integration suite | integration `*.tftest.hcl` deferred to verify-integration | `unrun` |
| [`day-2/17-mocking.md`](../labs/day-2/17-mocking.md) | S17 Mocking providers | `mock ✓ (no docker)` | None | `tests/unit.tftest.hcl` | `unit-tested` |
| [`day-2/18-terratest-cost.md`](../labs/day-2/18-terratest-cost.md) | S18 Integration, e2e & cost | `localstack ✓` · `mock ✓` | Docker; optional **Go** for Terratest lane | Terratest container in `setup/terratest/` | `unrun` |
| [`day-2/19-testing-cicd.md`](../labs/day-2/19-testing-cicd.md) | S19 Testing in CI/CD | `mock ✓ (paper + fixture · no docker)` | None | fixture YAML only | `unrun` |
| [`day-3/20-why-terramate.md`](../labs/day-3/20-why-terramate.md) | S20 Why Terramate | `mock ✓ (no docker)` | **Terramate** CLI | Terramate ~0.17.x (spoilers) | `unrun` |
| [`day-3/21-stacks.md`](../labs/day-3/21-stacks.md) | S21 Stacks | `mock ✓ (no docker)` (+ optional `localstack ✓`) | **Terramate** CLI | Terramate ~0.17.x | `unrun` |
| [`day-3/22-codegen.md`](../labs/day-3/22-codegen.md) | S22 Code generation | `mock ✓ (no docker)` | **Terramate** CLI | Terramate ~0.17.x | `unrun` |
| [`day-3/23-orchestration.md`](../labs/day-3/23-orchestration.md) | S23 Orchestration & ordering | `mock ✓ (no docker)` | **Terramate** CLI | Terramate ~0.17.x | `unrun` |
| [`day-3/24-change-detection.md`](../labs/day-3/24-change-detection.md) | S24 Change detection & filtering | `mock ✓ (no docker)` | **Terramate** CLI | Terramate ~0.17.x | `unrun` |
| [`day-3/25-terramate-ci-cloud.md`](../labs/day-3/25-terramate-ci-cloud.md) | S25 Terramate in CI + Cloud | `mock ✓ (paper + fixture · no docker)` | None | fixture YAML only | `unrun` |
| [`day-3/26-capstone.md`](../labs/day-3/26-capstone.md) | S26 Capstone & wrap-up | `localstack ✓` · `mock ✓` | Docker for Steps 5–6 (Part B build variant is mock-only) | capstone module + LocalStack; Part B reference `examples/capstone-build/` | `unrun` |
| [`day-3/27-terragrunt-comparison.md`](../labs/day-3/27-terragrunt-comparison.md) | S27 Terragrunt vs Terramate | `mock ✓ (paper + fixture · no docker)` | None (Terramate only for optional stretch) | read-only fixture HCL only | `unrun` |
| [`day-3/28-ecosystem-tooling.md`](../labs/day-3/28-ecosystem-tooling.md) | S28 Ecosystem tooling | `mock ✓ (no docker)` | **pre-commit** (one-time network hook fetch; tenv/terraform-docs optional) | hook repos pinned in `.pre-commit-config.yaml` | `unrun` |

## Tool-heavy labs: canonical install + expected diagnostic beat

These labs need extra tooling beyond OpenTofu. Each lists the canonical install and the
deliberate break→fix beat the rehearsal should confirm.

| Lab | Canonical tool install | Expected failure / diagnostic beat |
| --- | --- | --- |
| **S00** Setup | `task setup`; `task lab:up` before LocalStack steps | LocalStack health fails → fix Docker / port `:4566` before S3 apply |
| **S13** Static analysis | `tflint --init` in lab workdir | Unformatted / lint-failing HCL → `tflint` names the rule; fmt fixes it |
| **S14** Scanners | Trivy + Checkov + Conftest on `PATH` | Policy/scanner finding on intentional bad config → fix and re-scan clean |
| **S16** `tofu test` | Unit lane: plan-only tests; integration needs `task lab:up` | Broken assert → `tofu test` names the failing condition |
| **S18** Terratest / cost | Optional Go + `scripts/lab-terratest.sh` | Integration lane skipped without Docker — unit path stays green |
| **S20–S24** Terramate | Terramate CLI (`terramate version`) | Stack ordering / filter mistake → `terramate run` surfaces wrong stack set |
| **S26** Capstone | LocalStack up for AWS steps | Module output mismatch → trace through naming/state before apply |

## What this matrix feeds

- **US-P-VALDOCS** — inventory JSON + CI `--check`; a lab without a matrix row fails the build.
- **Rehearsal** — [`docs/rehearsal-checklist.md`](./rehearsal-checklist.md) is the human
  walk-through; [`docs/timing-results-template.md`](./timing-results-template.md) holds measured
  numbers. Promotion to `localstack-smoke` stays a deliberate maintainer edit after a recorded run.
- **Beta feedback** — file gaps via [`.github/ISSUE_TEMPLATE/beta-feedback.yml`](../.github/ISSUE_TEMPLATE/beta-feedback.yml).
