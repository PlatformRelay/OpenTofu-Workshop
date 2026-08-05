# ADR 0013: Single-file labs with sibling solution companions

- **Status:** accepted
- **Scope:** the internal layout of a lab — how a lab's prose, tracked workdir HCL,
  and reference solutions are stored and referenced. Complements
  [0009](0009-lab-workdirs.md), which established in-repo tracked workdirs instead of
  heredoc-into-`$HOME` flows.

## Context

[0009](0009-lab-workdirs.md) moved runnable HCL into sibling workdirs under
`labs/day-N/NN-topic/` and kept one participant Markdown file per lab. The participant
files still carry inline `<details>` spoilers for every step — workable for authoring,
but heavy for learners who only need answers after a good-faith attempt, and awkward
for facilitators who want a single spoiler destination.

The OpenTofu workshop ships **27 contracted labs** across Day 1–3 (see
`scripts/lab-contract.mjs`). CI should fail when a contracted lab lacks its sibling
solution, matching the Kubernetes workshop's enforced pattern without reintroducing a
per-lab `solutions/` folder tree.

## Options considered

1. **Keep inline `<details>` spoilers only.** Rejected — bloats the exercise file and
   duplicates content facilitators must hunt through step-by-step.
2. **Restore a per-lab `solutions/` folder tree.** Rejected — high churn; the sibling
   companion already separates answers without extra directories.
3. **Sibling `NN-topic.solution.md` beside the participant lab.** Chosen — one extra
   Markdown file per lab, linked at `#guided-solutions` and `#stretch-solution`, with
   `scripts/lab-contract.mjs` enforcing presence and minimum structure.

## Decision

A lab remains **one participant Markdown file**: `labs/day-N/NN-topic.md` (paired with
`pages/SNN-topic/` and a tracked workdir at `labs/day-N/NN-topic/` when the lab runs
HCL). Every contracted lab in `scripts/lab-contract.mjs` is paired with a sibling
**`NN-topic.solution.md`**.

Rules carried forward from [0009](0009-lab-workdirs.md):

- **Runnable HCL lives in the tracked workdir**; the participant lab references files
  by path and uses `<!-- source: … -->` drift markers where slide/lab fences must match
  tracked `.tf` files ([AGENT.md](../../AGENT.md) · lab workdir & drift contract).
- **Panic reset stays safe** — `task lab:down` and `tofu destroy` where applicable.

Rules for sibling solutions:

- **Answers live in the companion**, consolidating step spoilers, expected output, stretch
  paths, and recovery commands. Participant labs may still carry inline spoilers during
  migration; the companion is the facilitator-facing canonical answer key.
- **Required companion sections:** `Guided solutions`, `Expected state / output`,
  `Explanation`, `Troubleshooting and recovery`, `Stretch solution` (with
  `#guided-solutions` / `#stretch-solution` anchors).
- **CI enforces the inventory** via `pnpm lab:contract` / `node scripts/lab-contract.mjs`.
  A new contracted lab without a sibling solution fails the build naming the lab path.

## Consequences

- Facilitators can point stuck learners at one file without spoiling the participant
  lab for everyone else.
- `scripts/lab-contract.mjs` becomes the authoritative list of contracted labs; orphan
  participant files under `labs/day-*` must be listed or explicitly deferred.
- Migrating participant labs to spoiler-light link-only form is a follow-on lane; this
  ADR and CI gate the companion half first.
- Revert path: delete sibling `*.solution.md` files, remove the contract script and CI
  wiring, and mark this ADR superseded.
