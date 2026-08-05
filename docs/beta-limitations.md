## Known limitations

Honest leftovers for facilitators — not a release blocker, and **not** a pacing
contract. Room tempo depends on the presenter, the audience, and which optional
sections you keep.

- **The section library is a content superset** — `S00`–`S26` is deliberately
  larger than fits in three days. Even the **`core`** tier makes **Day 1 tight**
  at a ~6.5 h/day budget. Use the [Day 1 fit plan](https://platformrelay.github.io/OpenTofu-Workshop/#day-1-fit-plan)
  before facilitating; cut **`optional` first, then `recommended`**, and keep
  `core`.
- **Syllabus minute marks** are planning aids for facilitators, not measured
  delivery facts. Adjust on the day.
- **Day 2/3 tool-dependent labs** (TFLint, Trivy, Checkov, Conftest, Terramate,
  optional Terratest) have stronger unit/CI coverage than end-to-end clean runs on
  every host combination. Budget a dry-run of the add-ons *your* cut needs.
- **LocalStack paths** vary by lab; emulator health and install order can drift
  on a fresh machine — see [LocalStack troubleshooting](https://platformrelay.github.io/OpenTofu-Workshop/setup/localstack/).

> **Source of truth.** This file is the single tracked copy of the known-limitations
> statement. Pre-release tags (semver with a `-`, e.g. `v0.5.0-beta.1`) still prepend
> this file to auto-generated GitHub Release notes via `release.yml`. Edit here —
> do not fork the wording.
