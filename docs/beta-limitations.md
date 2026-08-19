## Known limitations

Honest leftovers for facilitators — not a release blocker, and **not** a pacing
contract. Room tempo depends on the presenter, the audience, and which optional
sections you keep.

- **The section library is a content superset** — `S00`–`S26` is deliberately
  larger than fits in three days, and the canonical three-day cut overflows too.
  Against a **390 min/day** budget (6.5 h), the planned slides+labs totals are
  **Day 1 = 780 — 390 over**, Day 2 = 360, and **Day 3 = 400 — 10 over**. Use the
  [Day 1 fit plan](https://platformrelay.github.io/OpenTofu-Workshop/#day-1-fit-plan)
  before facilitating — it compresses Day-1 *slide* time to 400 and leaves the
  245 minutes of Day-1 labs untouched; cut **`optional` first, then
  `recommended`**, and keep `core`.
- **Syllabus minute marks** are planning aids for facilitators, not measured
  delivery facts. Adjust on the day.
- **Day 2/3 tool-dependent labs** (TFLint, Trivy, Checkov, Conftest, Terramate,
  optional Terratest) have stronger unit/CI coverage than end-to-end clean runs on
  every host combination. Budget a dry-run of the add-ons *your* cut needs.
- **LocalStack paths** vary by lab; emulator health and install order can drift
  on a fresh machine — see [LocalStack troubleshooting](https://platformrelay.github.io/OpenTofu-Workshop/setup/localstack/).
- **Validation & rehearsal** — per-lab environment/tool claims and honest
  validation states live in [`docs/validation-matrix.md`](./validation-matrix.md)
  (machine view: `infra/lab-inventory.json`). No lab is marked fully rehearsed
  (`localstack-smoke`) yet; use [`docs/rehearsal-checklist.md`](./rehearsal-checklist.md)
  and [`docs/timing-results-template.md`](./timing-results-template.md) before claiming timings.

> **Source of truth.** This file is the single tracked copy of the known-limitations
> statement. Pre-release tags (semver with a `-`, e.g. `v0.5.0-beta.1`) still prepend
> this file to auto-generated GitHub Release notes via `release.yml`. Edit here —
> do not fork the wording.
